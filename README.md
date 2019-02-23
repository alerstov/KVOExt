## KVOExt

[![Build Status](https://travis-ci.org/alerstov/KVOExt.svg)](https://travis-ci.org/alerstov/KVOExt)
[![codebeat badge](https://codebeat.co/badges/62a7e551-c8b5-41d3-bdd2-df868a5ebb51)](https://codebeat.co/projects/github-com-alerstov-kvoext-master)

Simplify work with KVO.

## Features
- simple syntax
- strongly typed keypath
- automatic observer removal
- handler blocks implicitly retained by listener
- handler block does not retain self
- support lazy binding
- can replace delegation, target-action patterns
- NOT THREAD SAFE (work only on main thread)

## Usage
### Bind/observe
```objective-c
observe(src, propName) { ... }
bind(src, propName) { ... }
```
`observe` - start listening src.propName, handler block will be triggered on next calling of propName setter.  
`bind` - start listening src.propName and immediately trigger handler block.
In handler block use keyword `value` to access to observable value.

### Manual unbind
```objective-c
bind(src, propName, key) { ... }
unbind(key)
```
`key` - like key for dictionary, should confirm to the NSCopying, typical it's string.

### Lazy binding
Use class name instead source object for lazy binding.
```objective-c
bind(ClsName, propName) { ... }
self.dataContext = src;
```
Binding "activate" after dataContext assigned.  
`dataContext` can be set before binding declaration.  
`src` class should be kind of `ClsName`.  
Each NSObject has implict property `dataContext`.


### Event emulation macros
Declare event. Second optional param - argument type.
```objective-c
event_prop(change, MyClass*); 	// @property (nonatomic) MyClass* change;
event_prop(loading, BOOL);		// @property (nonatomic) BOOL loading;
event_prop(complete);			// @property (nonatomic) id complete;
```

Raise event
```objective-c
event_raise(loading, YES);		// self.loading = YES;
event_raise(complete);			// self.complete = nil;
```

Listen event
```objective-c
observe(src, loading) { ... }
```

### Start/stop observing
Execute some code on start/stop observing of properties. Useful for UI. See examples.
```objective-c
on_start_observing(ClsName, propName) {
    // <start observing code >
};

on_stop_observing(ClsName, propName) {
    // <stop observing code >
};
```


## Examples

#### Reactive style, dependence on multiple sources
```objective-c
@interface MyModel : NSObject
@property (nonatomic) NSString* name;
@property (nonatomic) NSString* surname;
@property (nonatomic) NSInteger age;
@end

@interface MyViewModel : NSObject
@property (nonatomic) NSString* fullname;
@property (nonatomic) NSString* age;
@end
@implementation MyViewModel
{
    MyModel* _model;
}
- (instancetype)initWithModel:(MyModel*)model {
    self = [super init];
    if (self) {
        _model = model;
        
        bind(model, age) { self.age = [NSString stringWithFormat:@"age: %@ ", @(value)]; };
        
        observe(model, name) { [self check]; };
        observe(model, surname) { [self check]; };
        [self check];
    }
    return self;
}

-(void)check {
    self.fullname = [NSString stringWithFormat:@"%@ %@", _model.name, _model.surname];
}
@end
```

#### Observe self properties (write less damn code)
```objective-c
@interface MyView : UIView
@property (nonatomic) NSString* text;
@end

@implementation MyView
-(void)setup {
    UILabel* label = [UILabel new];
    [self addSubview:label];

    observe(self, text) {
        label.text = value;
    };
}
@end
```

#### UIButton click helper
```objective-c
@interface UIButton (ClickHelper)
event_prop(click);
@end
@implementation UIButton (ClickHelper)
+(void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        on_start_observing(UIButton, click) {
            [self addTarget:self action:@selector(_onTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
        };
        on_stop_observing(UIButton, click) {
            if (!inDealloc) {
                [self removeTarget:self action:@selector(_onTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
            }
        };
    });
}
-(void)_touchUpInside {
    event_raise(click);
}
-(id)click { return nil; }
-(void)setClick:(id)click {}
@end

@implementation MyView
-(void)setup {
    UIButton* but = [UIButton new];
    [self addSubview:but];

    observe(but, click) {
        NSLog(@"button click");
    };
}
@end
```

#### MVVM
```objective-c
@interface MyViewModel : NSObject
@property (nonatomic) NSString* text;
@end

@implementation MyView
-(void)setup {
    UILabel* label = [UILabel new];
    [self addSubview:label];
    
    bind(MyViewModel, text) {
        label.text = value;
    };
}
@end

@implementation ViewController
-(void)viewDidLoad {
    MyView* view = [MyView new];
    [self.view addSubview:view];
    
    MyViewModel* vm = [MyViewModel new]; // it's not good instatiate view model in view controller, just for example
    vm.text = @"hello";
    view.dataContext = vm;
    
    observe(self.view, tap) {
        vm.text = @"hello, world";
    };
}
@end
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
