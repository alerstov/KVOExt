//
//  Created by Alexander Stepanov on 02/06/16.
//  Copyright © 2016 Alexander Stepanov. All rights reserved.
//

#import <Foundation/Foundation.h>

// bind - with initial assign
// observe - no initial assign

// 1. Direct binding
// bind(src, keypath) { self.prop = value; }

// 2. Lazy binding
// bind(DataSource, keypath) { self.prop = value; }
// bindx(keypath) { self.prop = [value boolValue]; }
// ...
// self.dataContext = src;

// 3. Manual unbinding
// bind(src1, keypath1, group_key) { ... }
// bind(src2, keypath2, group_key) { ... }
// ...
// unbind(group_key);

// 4. Event macros
// event_prop(loading, BOOL);
// event_prop(complete);
//
// event_raise(loading, YES);
// event_raise(complete);


#define bind(src, keypath, ...) _observe_static(YES, src, keypath, ##__VA_ARGS__)
#define observe(src, keypath, ...) _observe_static(NO, src, keypath, ##__VA_ARGS__)

#define bindx(keypath, ...) _observe_dynamic(YES, keypath, ##__VA_ARGS__)
#define observex(keypath, ...) _observe_dynamic(NO, keypath, ##__VA_ARGS__)

#define unbind(key) [self _kvoext_unbind:key]

#define event_prop(name, ...) @property (nonatomic) _kvoext_macro(name, ##__VA_ARGS__, id) name
#define event_raise(name, ...) self.name = _kvoext_macro(name, ##__VA_ARGS__, nil)

#define on_start_observing(cls, keypath) \
NSAssert(self == [cls class], @"invalid clsass"); \
_kvoext_keyPath = (__typeof((((cls*)0).keypath), @""))@#keypath; \
self._kvoext_startObservingBlock = ^(cls* self)

#define on_stop_observing(cls, keypath) \
NSAssert(self == [cls class], @"invalid clsass"); \
_kvoext_keyPath = (__typeof((((cls*)0).keypath), @""))@#keypath; \
self._kvoext_stopObservingBlock = ^(cls* self, BOOL inDealloc)

#define is_observing(obj, keypath) \
[obj _kvoext_isObservingKeyPath:(__typeof((obj.keypath), @""))@#keypath]

@interface NSObject (KVOExt)
@property (nonatomic) id dataContext;
@end


//-----------------------------------------------------------
#define _kvoext_macro(_0, X, ...) X

#if DEBUG
#define _kvoext_save_retain_count() _kvoext_retain_count = CFGetRetainCount((__bridge CFTypeRef)self);
#else
#define _kvoext_save_retain_count()
#endif

#define _observe_static(initial, src, keypath, ...) \
_kvoext_source = [src _kvoext_source]; \
_kvoext_groupKey = _kvoext_macro(0, ##__VA_ARGS__, nil); \
_kvoext_raiseInitial = initial; \
_kvoext_keyPath = @#keypath; \
_kvoext_argType = @encode(__typeof([src _kvoext_new].keypath)); \
_kvoext_save_retain_count() \
self._kvoext_block = ^(__typeof(self) self, __typeof([src _kvoext_new].keypath) value)

#define _observe_dynamic(initial, keypath, ...) \
_kvoext_source = nil; \
_kvoext_groupKey = _kvoext_macro(0, ##__VA_ARGS__, nil); \
_kvoext_raiseInitial = initial; \
_kvoext_keyPath = @#keypath; \
_kvoext_argType = NULL; \
_kvoext_save_retain_count() \
self._kvoext_block = ^(__typeof(self) self, id value)

extern id _kvoext_source;
extern NSString* _kvoext_keyPath;
extern BOOL _kvoext_raiseInitial;
extern const char* _kvoext_argType;
extern id _kvoext_groupKey;
#if DEBUG
extern long _kvoext_retain_count;
#endif


@interface NSObject (KVOExtPrivate)

-(void)set_kvoext_block:(id)block;
-(void)_kvoext_unbind:(id)key;
-(void)set_kvoext_startObservingBlock:(id)block;
-(void)set_kvoext_stopObservingBlock:(id)block;
-(BOOL)_kvoext_isObservingKeyPath:(NSString *)keyPath;

-(instancetype)_kvoext_new; // self
+(instancetype)_kvoext_new; // [self new]

-(id)_kvoext_source; // self
+(id)_kvoext_source; // class

@end
