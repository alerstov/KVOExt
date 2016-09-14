//
//  Created by Alexander Stepanov on 02/06/16.
//  Copyright © 2016 Alexander Stepanov. All rights reserved.
//

#import "KVOExt.h"
#import <objc/runtime.h>


static id _kvoext_tmp;

static const void *ObserverKey = &ObserverKey;
static const void *BindingsKey = &BindingsKey;

static const void *DataContextKey = &DataContextKey;
static const void *LazyBindingsKey = &LazyBindingsKey;


typedef void(^KVOExtBlockInvoker)(id value);


typedef NS_OPTIONS(int, BlockFlags) {
    BlockFlagsHasCopyDisposeHelpers = (1 << 25),
    BlockFlagsHasSignature          = (1 << 30)
};

typedef struct _Block {
    __unused Class isa;
    BlockFlags flags;
    __unused int reserved;
    void (__unused *invoke)(struct _Block *block, ...);
    struct {
        unsigned long int reserved;
        unsigned long int size;
        // requires BlockFlagsHasCopyDisposeHelpers
        void (*copy)(void *dst, const void *src);
        void (*dispose)(const void *);
        // requires BlockFlagsHasSignature
        const char *signature;
        const char *layout;
    } *descriptor;
    // imported variables
} *BlockRef;


static NSMethodSignature* typeSignatureForBlock(id block) {
    BlockRef layout = (__bridge void *)block;
    
    if (layout->flags & BlockFlagsHasSignature) {
        void *desc = layout->descriptor;
        desc += 2 * sizeof(unsigned long int);
        
        if (layout->flags & BlockFlagsHasCopyDisposeHelpers) {
            desc += 2 * sizeof(void *);
        }
        
        if (desc) {
            const char *signature = (*(const char **)desc);
            return [NSMethodSignature signatureWithObjCTypes:signature];
        }
    }
    
    return nil;
}

static KVOExtBlockInvoker typedInvoker(id owner, const char* argType, id block1) {
    id block = [block1 copy];
    
    NSMethodSignature* sig = typeSignatureForBlock(block);
    NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:sig];
    //[invocation setTarget:block];
    [invocation setArgument:&owner atIndex:1];
    
    // Skip const type qualifier.
    if (argType[0] == 'r') {
        argType++;
    }
    
    // id, Class
    if (strcmp(argType, @encode(id)) == 0 || strcmp(argType, @encode(Class)) == 0) {
        return ^(id value){
            [invocation setArgument:&value atIndex:2];
            [invocation invokeWithTarget:block];
        };
    }
    
#define WRAP(type, selector) \
do { \
if (strcmp(argType, @encode(type)) == 0) { \
return ^(id value){ \
type val = [value selector]; \
[invocation setArgument:&val atIndex:2]; \
[invocation invokeWithTarget:block]; \
}; \
} \
} while (0)
    
    WRAP(char, charValue);
    WRAP(int, intValue);
    WRAP(short, shortValue);
    WRAP(long, longValue);
    WRAP(long long, longLongValue);
    WRAP(unsigned char, unsignedCharValue);
    WRAP(unsigned int, unsignedIntValue);
    WRAP(unsigned short, unsignedShortValue);
    WRAP(unsigned long, unsignedLongValue);
    WRAP(unsigned long long, unsignedLongLongValue);
    WRAP(float, floatValue);
    WRAP(double, doubleValue);
    WRAP(BOOL, boolValue);
    
#undef WRAP
    
    // char*
    if (strcmp(argType, @encode(char *)) == 0) {
        return ^(id value){
            const char *cString = [value UTF8String];
            [invocation setArgument:&cString atIndex:2];
            [invocation invokeWithTarget:block];
        };
    }
    
    // block
    if (strcmp(argType, @encode(void (^)(void))) == 0) {
        return ^(id value){
            [invocation setArgument:&value atIndex:2];
            [invocation invokeWithTarget:block];
        };
    }
    
    // NSValue
    return ^(id value){
        NSCParameterAssert([value isKindOfClass:NSValue.class]);
        
        NSUInteger valueSize = 0;
        NSGetSizeAndAlignment([value objCType], &valueSize, NULL);
        
#if DEBUG
        NSUInteger argSize = 0;
        NSGetSizeAndAlignment(argType, &argSize, NULL);
        NSCAssert(valueSize == argSize, @"Value size does not match argument size: %@", value);
#endif
        
        unsigned char valueBytes[valueSize];
        [value getValue:valueBytes];
        
        [invocation setArgument:valueBytes atIndex:2];
        [invocation invokeWithTarget:block];
    };
}










#pragma mark -

@interface KVOExtObserver : NSObject
@end

@interface KVOExtWeakRef : NSObject
{
@public
    id __weak weakObj;
}
@end

@interface KVOExtToken : NSObject
{
@public
    id __weak weakObj;
}
@property (nonatomic, copy) void(^unbindBlock)(id obj);
@end

@interface KVOExtLazyBinding : NSObject
@property (nonatomic) KVOExtToken* bindToken;
@property (nonatomic, copy) KVOExtToken*(^bindBlock)(id src);
@end




#pragma mark -

@implementation KVOExtToken
-(void)unbind {
    id obj = self->weakObj;
    if (obj != nil) {
        self.unbindBlock(obj);
    }
}
@end

@implementation KVOExtWeakRef
@end

@implementation KVOExtLazyBinding
@end


@implementation KVOExtObserver
{
    id __unsafe_unretained _dataSource;
    NSMutableDictionary* _bindingsDictionary;
}

- (instancetype)initWithDataSource:(id)source {
    self = [super init];
    if (self) {
        _dataSource = source;
        _bindingsDictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

-(void)addBlock:(id)block forKeyPath:(NSString*)keyPath {
    NSMutableSet* set = _bindingsDictionary[keyPath];
    BOOL shouldAddObserver = set == nil;
    if (shouldAddObserver) {
        set = [NSMutableSet set];
        _bindingsDictionary[keyPath] = set;
        
        // observe
        [_dataSource addObserver:self forKeyPath:keyPath options:0 context:NULL];
    }
    
    KVOExtWeakRef* weakRef1 = nil;
    for (KVOExtWeakRef *weakRef in set) {
        KVOExtBlockInvoker block = weakRef->weakObj;
        if (block == nil) {
            weakRef1 = weakRef;
            break;
        }
    }
    
    if (weakRef1 == nil){
        weakRef1 = [KVOExtWeakRef new];
        [set addObject:weakRef1];
    }
    
    weakRef1->weakObj = block;
    
    if (shouldAddObserver) {
        [_dataSource didAddObserverForKeyPath:keyPath];
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {

    id val = [_dataSource valueForKey:keyPath];
    
    NSMutableSet* set = _bindingsDictionary[keyPath];
    BOOL shouldRemoveObserver = YES;
    for (KVOExtWeakRef *weakRef in [set copy]) {
        KVOExtBlockInvoker block = weakRef->weakObj;
        if (block != nil) {
            shouldRemoveObserver = NO;
            block(val);
        }
    }
    
    if (shouldRemoveObserver) {
        // remove observer
        [_dataSource removeObserver:self forKeyPath:keyPath];
        [_bindingsDictionary removeObjectForKey:keyPath];
        
        [_dataSource didRemoveObserverForKeyPath:keyPath];
    }
}

// on source released
-(void)dealloc {
    for (NSString* keyPath in _bindingsDictionary) {
        // remove observer
        [_dataSource removeObserver:self forKeyPath:keyPath];
        
        [_dataSource didRemoveObserverInDeallocForKeyPath:keyPath];
    }
}

@end







#pragma mark -  NSObject (KVOExt)

@implementation NSObject (KVOExt)

-(id)_kvoext_observeKeyPath:(NSString *)keyPath raiseInitial:(BOOL)initial source:(id)src argType:(const char *)argType {
    assert(keyPath != nil);
    
    KVOExtToken* token = [KVOExtToken new];

    _kvoext_tmp = [^(id block) {
        
        if (src == nil) { // lazy binding
            
            KVOExtLazyBinding* lazyBinding = [KVOExtLazyBinding new];
            
            NSObject* __unsafe_unretained owner = self;
            lazyBinding.bindBlock = ^(id dataSource) {
                
                id token = [owner _kvoext_observeKeyPath:keyPath raiseInitial:initial source:dataSource argType:argType];
                owner._kvoext_block = block;

                return token;
            };
            
            // retain lazy binding
            NSMutableSet *bindings = objc_getAssociatedObject(self, LazyBindingsKey);
            if (bindings == nil){
                bindings = [NSMutableSet set];
                objc_setAssociatedObject(self, LazyBindingsKey, bindings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            [bindings addObject:lazyBinding];
            
            
            // complete token
            token->weakObj = lazyBinding;
            NSMutableSet* __weak weakBindings = bindings;
            token.unbindBlock = ^(KVOExtLazyBinding* obj) {
                [obj.bindToken unbind];
                [weakBindings removeObject:obj];
            };
            
            
            // bind if source exists
            id dataSource = objc_getAssociatedObject(self, DataContextKey);
            if (dataSource != nil) {
                lazyBinding.bindToken = lazyBinding.bindBlock(dataSource);
            }
            
        } else { // direct binding
            
            KVOExtBlockInvoker block1;
            if (argType != NULL) {
                // static typed
                block1 = typedInvoker(self, argType, block);
            }else{
                // dynamic typed
                id __unsafe_unretained owner = self;
                block1 = ^(id value){ ((void(^)(id, id))block)(owner, value); };
            }
            block1 = [block1 copy];
            
            
            // source observer
            KVOExtObserver* observer = objc_getAssociatedObject(src, ObserverKey);
            if (observer == nil) {
                observer = [[KVOExtObserver alloc] initWithDataSource:src];
                objc_setAssociatedObject(src, ObserverKey, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            [observer addBlock:block1 forKeyPath:keyPath];
            
            
            // retain binding
            NSMutableSet *bindings = objc_getAssociatedObject(self, BindingsKey);
            if (bindings == nil) {
                bindings = [NSMutableSet set];
                objc_setAssociatedObject(self, BindingsKey, bindings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            [bindings addObject:block1];
            
            
            // complete token
            token->weakObj = block1;
            NSMutableSet* __weak weakBindings = bindings;
            token.unbindBlock = ^(id obj) {
                [weakBindings removeObject:obj];
            };
            
            
            // raise initial
            if (initial) {
                id val = [src valueForKey:keyPath];
                block1(val);
            }
        }
    } copy];
    
    return token;
}

-(void)set_kvoext_block:(id)block {
    assert(block != nil);
    
    void(^block1)(id) = _kvoext_tmp;
    _kvoext_tmp = nil;
    block1(block);
}

-(void)unbind { }

-(instancetype)_kvoext_new { return self; }
+(instancetype)_kvoext_new { return [self new]; }

-(id)_kvoext_source { return self; }
+(id)_kvoext_source { return nil; }

-(id)dataContext {
    return objc_getAssociatedObject(self, DataContextKey);
}

-(void)setDataContext:(id)dataContext {
    objc_setAssociatedObject(self, DataContextKey, dataContext, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    NSMutableSet *bindings = objc_getAssociatedObject(self, LazyBindingsKey);
    for (KVOExtLazyBinding* b in [bindings copy]) {
        // remove old
        [b.bindToken unbind];
        
        // create new
        if (dataContext != nil){
            b.bindToken = b.bindBlock(dataContext);
        }
    }
}

-(void)didAddObserverForKeyPath:(NSString*)keyPath {}
-(void)didRemoveObserverForKeyPath:(NSString *)keyPath {}
-(void)didRemoveObserverInDeallocForKeyPath:(NSString *)keyPath {}

@end