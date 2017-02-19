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
// bind(keypath) { self.prop = [value boolValue]; }
// ...
// self.dataContext = src;

// 3. Manual unbinding
// id token = bind(...) { ... }
// ...
// [token unbind];

// 4. Event macros
// event_prop(loading, BOOL);
// event_prop(complete);
//
// event_raise(loading, YES);
// event_raise(complete);


#define event_prop(name, ...) @property (nonatomic) _event_macro(name, ##__VA_ARGS__, id) name
#define event_raise(name, ...) self.name = _event_macro(name, ##__VA_ARGS__, nil)
#define _event_macro(_0, X, ...) X


#define bind(...) _observe(YES, __VA_ARGS__)
#define observe(...) _observe(NO, __VA_ARGS__)


#define _observe(initial, ...) _observe_macro(__VA_ARGS__, _observe_static, _observe_dynamic)(__VA_ARGS__, initial)
#define _observe_macro(_0, _1, X, ...) X

#define _observe_static(src, keypath, initial) \
[self _kvoext_observeKeyPath:@#keypath raiseInitial:initial source:[src _kvoext_source] argType:@encode(__typeof([src _kvoext_new].keypath))]; \
self._kvoext_block = ^(__typeof(self) self, __typeof([src _kvoext_new].keypath) value)

#define _observe_dynamic(keypath, initial) \
[self _kvoext_observeKeyPath:@#keypath raiseInitial:initial source:nil argType:NULL]; \
self._kvoext_block = ^(__typeof(self) self, id value)


#define on_stop_observing self._kvoext_stopObservingBlock = ^(__typeof(self) self)


@interface NSObject (KVOExt)

-(void)didStartObservingKeyPath:(NSString*)keyPath;
-(void)set_kvoext_stopObservingBlock:(id)block;

@property (nonatomic) id dataContext;
-(void)unbind;

// internal
-(id)_kvoext_observeKeyPath:(NSString*)keyPath raiseInitial:(BOOL)initial source:(id)src argType:(const char*)argType;
-(void)set_kvoext_block:(id)block;

-(instancetype)_kvoext_new; // self
+(instancetype)_kvoext_new; // [self new]

-(id)_kvoext_source; // self
+(id)_kvoext_source; // nil

@end