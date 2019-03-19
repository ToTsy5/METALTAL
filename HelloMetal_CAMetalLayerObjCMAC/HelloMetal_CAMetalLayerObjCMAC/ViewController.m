//
//  ViewController.m
//  HelloMetal_CAMetalLayerObjCMAC
//
//  Created by toshi on 2018/10/12.
//  Copyright © 2018 toshi. All rights reserved.
//
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

#import "ViewController.h"


@interface InputView : NSView
@end
@implementation InputView
- (BOOL)acceptsFirstResponder
{
    return YES;
}
-(void) keyDown:(NSEvent *)event
{
    switch (event.keyCode)
    {
    case 126:
        NSLog(@"UP");
        break;
    case 125:
        NSLog(@"DOWN");
        break;
    case 123:
        NSLog(@"LEFT");
        break;
    case 124:
        NSLog(@"RIGHT");
        break;
    case 49:
        NSLog(@"SPACE");
        break;
    case 36:
        NSLog(@"ENTER");
        break;
    }
}
@end





@implementation ViewController
{
    InputView* inputview;
    
    id<MTLDevice>              device;
    id<MTLBuffer>              vertexBuffer;
    MTLVertexDescriptor*       vertexDescriptor;//toshi added
    CAMetalLayer*              metalLayer;
    id<MTLRenderPipelineState> pipelineState;
    id<MTLCommandQueue>        commandQueue;
    //CADisplayLink*             timer;
}




//macOSにはiOSにあるCADisplayLinkは存在しなくて、代わりにCVDisplayLinkなるものを使う。toshi
static CVReturn gameloop(CVDisplayLinkRef displayLink,
                               const CVTimeStamp *inNow,
                               const CVTimeStamp *inOutputTime,
                               CVOptionFlags flagsIn,
                               CVOptionFlags *flagsOut,
                               void *displayLinkContext);
- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.

    inputview = [[InputView alloc] init];
    inputview.frame = self.view.frame;
    [self.view addSubview:inputview];
    

    // MTLDeivceの生成
    device = MTLCreateSystemDefaultDevice();
    
    // CAMetalLayerの生成
    metalLayer = [CAMetalLayer layer];
    metalLayer.device          = device;
    metalLayer.pixelFormat     = MTLPixelFormatBGRA8Unorm;
    metalLayer.framebufferOnly = YES;
    metalLayer.frame           = self.view.layer.frame;
    [self.view.layer addSublayer:metalLayer];
    
#if 1
    // 頂点情報
    float vertexData[] = {
        0.0,  1.0, 0.0,
        -1.0, -1.0, 0.0,
        1.0, -1.0, 0.0,
    };
    
    //NSInteger t = sizeof(CGFloat);//注意！CGFloatは8bit、floatと違うので間違えて使うな！！！参照したWEBでCGFloat使ってたので少しハマった。。
    
    NSInteger dataSize = sizeof(vertexData);
    vertexBuffer = [device newBufferWithBytes:vertexData length:dataSize options:MTLResourceOptionCPUCacheModeDefault];
    
    
    //toshia added
    vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    vertexDescriptor.attributes[0].format      = MTLVertexFormatFloat3;
    vertexDescriptor.attributes[0].offset      = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.layouts[0].stride         = 12;
    vertexDescriptor.layouts[0].stepRate       = 1;
    vertexDescriptor.layouts[0].stepFunction   = MTLVertexStepFunctionPerVertex;
    
    
    //RENDER PIPELINE
    
    //id <MTLRenderPipelineState> pipelineState;
    
    id <MTLLibrary> defaultLibrary   = [device newDefaultLibrary];
    id <MTLFunction> fragmentProgram = [defaultLibrary newFunctionWithName:@"basic_fragment"];
    id <MTLFunction> vertexProgram   = [defaultLibrary newFunctionWithName:@"basic_vertex"];
    
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.vertexFunction   = vertexProgram;
    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor;//toshi added
    pipelineStateDescriptor.fragmentFunction = fragmentProgram;
    //    [pipelineStateDescriptor.colorAttachments objectAtIndexedSubscript:0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    NSError *pipelineError = nil;
    pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&pipelineError];
    
    if (!pipelineState) {
        NSLog(@"Failed to create pipeline state, error %@", pipelineError);
    }
#endif
    

    //COMMAND QUEUE
    commandQueue = [device newCommandQueue];

    
    //DISPLAY LINK
    //macOSにはiOSにあるCADisplayLinkは存在しなくて、代わりにCVDisplayLinkなるものを使う。toshi
#if 0
    timer = [CADisplayLink displayLinkWithTarget:self selector:@selector(gameloop)];
    [timer addToRunLoop:NSRunLoop.mainRunLoop forMode:NSDefaultRunLoopMode];
#else
    CVDisplayLinkRef    displayLink;
    CGDirectDisplayID   displayID = CGMainDisplayID();
    CVReturn            error = kCVReturnSuccess;
    error = CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink);
    if (error)
    {
        NSLog(@"DisplayLink created with error:%d", error);
        displayLink = NULL;
    }
    CVDisplayLinkSetOutputCallback(displayLink, gameloop, (__bridge void *)self);
    
    CVDisplayLinkStart(displayLink);
#endif
}


NSInteger getRetainCount(__strong id obj) {
    return CFGetRetainCount((__bridge CFTypeRef)obj);
}
- (void) render
{
    // Render Pass Descriptorの生成。
    id<CAMetalDrawable> drawable = metalLayer.nextDrawable;//toshi added
    
    MTLRenderPassDescriptor *renderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
    renderPassDescriptor.colorAttachments[0].texture     = drawable.texture;
    renderPassDescriptor.colorAttachments[0].loadAction  = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].clearColor  = MTLClearColorMake(0.0, 104.0/255.0, 5.0/255.0, 1.0);
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    NSLog(@"count %d", (int) getRetainCount(drawable.texture));
    
    //toshi added
    //renderPassDescriptor.renderTargetWidth               = self.view.frame.size.width;
    //renderPassDescriptor.renderTargetHeight              = self.view.frame.size.height;
    
    
    // create a new command queue
    //id<MTLCommandQueue> _commandQueue = [device newCommandQueue];
    
    id <MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

    // Render Command Encoderの生成
    id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
#if 1
    if (renderEncoder) {
        [renderEncoder setRenderPipelineState:pipelineState];
        [renderEncoder setVertexBuffer:vertexBuffer offset:0 atIndex:0];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3 instanceCount:1];
        [renderEncoder endEncoding];
    }
    
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
#else
    //-----------------------------
    //renderループが止まる現象のテスト
    //-----------------------------
    [renderEncoder endEncoding];
    [commandBuffer commit];

    
    commandBuffer = [commandQueue commandBuffer];
    renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder endEncoding];
#if 1
    //macではこれがないと、数ループ後に停止する
    [commandBuffer commit];
#endif
    
#if 1
    commandBuffer = [commandQueue commandBuffer];
    renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder setRenderPipelineState:pipelineState];
    [renderEncoder setVertexBuffer:vertexBuffer offset:0 atIndex:0];
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3 instanceCount:1];
    [renderEncoder endEncoding];
    [commandBuffer commit];
#endif
    
    commandBuffer = [commandQueue commandBuffer];
    commandBuffer.label = @"MetalPass::End()";
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
#endif
    
    //NSLog(@"render");
}

#if 0
- (void)gameloop
{
    @autoreleasepool {
        [self render];
    }
}
#else
//macOSにはiOSにあるCADisplayLinkは存在しなくて、代わりにCVDisplayLinkなるものを使う。toshi
static CVReturn gameloop(CVDisplayLinkRef displayLink,
                         const CVTimeStamp *inNow,
                         const CVTimeStamp *inOutputTime,
                         CVOptionFlags flagsIn,
                         CVOptionFlags *flagsOut,
                         void *displayLinkContext)
{
    //return [(__bridge SPVideoView *)displayLinkContext renderTime:inOutputTime];
    
    //NSLog(@"renderCallback");
    
    if (displayLinkContext) {
        ViewController* viewcontroller = (__bridge ViewController*)displayLinkContext;
        
        @autoreleasepool {
            [viewcontroller render];
        }
    }
    
    return kCVReturnSuccess;
}
#endif


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

@end
