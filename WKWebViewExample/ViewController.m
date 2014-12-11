/*
 *  ViewController.m
 *  WKWebViewExample
 *
 *
 *  Created by Priya Rajagopal on 12/08/14.
 *  Copyright (c) 2012 Lunaria Software,LLC. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ViewController.h"
@import Foundation;
@import WebKit;

#pragma mark - private interface
@interface ViewController () <WKScriptMessageHandler, WKNavigationDelegate>
@property (nonatomic,strong) WKWebView* webView;
@property (nonatomic,assign)NSInteger buttonClicked;
@property (nonatomic,strong)NSArray* colors;
@property (nonatomic, strong) WKWebViewConfiguration * webConfig;
@end

#pragma mark - Implementation
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view, typically from a nib.
    self.colors = @[@"0xff00ff",@"#ff0000",@"#ffcc00",@"#ccff00",@"#ff0033",@"#ff0099",@"#cc0099",@"#0033ff",@"#0066ff",@"#ffff00",@"#0000ff",@"#0099cc"];
    
    // Create a WKWebView instance
    self.webView = [[WKWebView alloc]initWithFrame:self.view.frame configuration:self.webConfig];
    
    // Delegate to handle navigation of web content
    self.webView.navigationDelegate = self;
    
    [self.view addSubview:self.webView];
    
  }

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Load the HTML document
    [self loadHtml];

}


-(void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.webView = nil;
    self.colors = nil;
    self.webConfig = nil;
#ifndef _DEVICE_LOAD_ISSUE_FIXED
    NSError *error = nil;
    NSString *fileName = [NSString stringWithFormat:@"%@_%@", [[NSProcessInfo processInfo] globallyUniqueString], @"TestFile.html"];
    NSString* tempHtmlPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

    [[NSFileManager defaultManager] removeItemAtPath:tempHtmlPath error:&error];
#endif
}

-(void)loadHtml {
    // NOTE: Due to a bug in webKit as of iOS 8.1.1 we CANNOT load a local resource when running on device.
    
    NSString* htmlPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestFile" ofType:@"html"];

#ifndef _DEVICE_LOAD_ISSUE_FIXED
    NSError* error;
    NSString *fileName = [NSString stringWithFormat:@"%@_%@", [[NSProcessInfo processInfo] globallyUniqueString], @"TestFile.html"];
    NSString* tempHtmlPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    [[NSFileManager defaultManager]copyItemAtPath:htmlPath toPath:tempHtmlPath error:&error];
   
    htmlPath = tempHtmlPath;
#endif
    
    if (htmlPath) {
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:htmlPath]]];
    }else {
        [self showAlertWithMessage:@"Could not load HTML file!"];
    }
}


#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"%s",__func__);
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"%s. Error %@",__func__,error);
    [self showAlertWithMessage:[NSString stringWithFormat:@"Failed to load file with Error: %@",error.localizedDescription]];
}

#pragma mark -WKScriptMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"buttonClicked"]) {
        self.buttonClicked ++;
    }
 
    // JS objects are automatically mapped to ObjC objects
    id messageBody = message.body;
    if ([messageBody isKindOfClass:[NSDictionary class]]) {
        NSString* idOfTappedButton = messageBody[@"ButtonId"];
        [self updateColorOfButtonWithId:idOfTappedButton];
    }
   
}

#pragma mark - accessors
-(WKWebViewConfiguration*) webConfig {
    
    if (!_webConfig) {
        // Create WKWebViewConfiguration instance
        _webConfig = [[WKWebViewConfiguration alloc]init];
        
        // Setup WKUserContentController instance for injecting user script
        WKUserContentController* userController = [[WKUserContentController alloc]init];
        
        // Add a script message handler for receiving  "buttonClicked" event notifications posted from the JS document using window.webkit.messageHandlers.buttonClicked.postMessage script message
        [userController addScriptMessageHandler:self name:@"buttonClicked"];
        
        // Get script that's to be injected into the document
        NSString* js = [self buttonClickEventTriggeredScriptToAddToDocument];
        
        // Specify when and where and what user script needs to be injected into the web document
        WKUserScript* userScript = [[WKUserScript alloc]initWithSource:js injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
        
        // Add the user script to the WKUserContentController instance
        [userController addUserScript:userScript];
        
        // Configure the WKWebViewConfiguration instance with the WKUserContentController
        _webConfig.userContentController = userController;
        
    }
    return _webConfig;
    
}

#pragma mark - helpers
-(NSString*)buttonClickEventTriggeredScriptToAddToDocument {
    
    // Script: When window is loaded, execute an anonymous function that adds a "click" event handler function to the "ClickMeButton" button element. The "click" event handler calls back into our native code via the window.webkit.messageHandlers.buttonClicked.postMessage call
    
    NSString* script =[NSString stringWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"ClickMeEventRegister" ofType:@"js" ] encoding:NSUTF8StringEncoding error:nil];
    return script;
}

-(void)updateColorOfButtonWithId:(NSString*)buttonId {
    
    // update the button color by evaluating a JS
    
    NSInteger index = arc4random_uniform((int)self.colors.count);
    NSString* color = self.colors[index];
    
    // Script that changes the color of tapped button
    NSString* js2 = [NSString stringWithFormat:@"var button = document.getElementById('%@'); button.style.backgroundColor='%@';",buttonId,color];

     [self.webView evaluateJavaScript:js2 completionHandler:^(id response, NSError * error) {
         NSLog(@"%@",error);
     }];
    
}

-(void)showAlertWithMessage:(NSString*)message {
    UIAlertAction* action = [UIAlertAction actionWithTitle:NSLocalizedString(@"CANCEL", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    UIAlertController* alertVC = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertVC addAction:action];
    [self presentViewController:alertVC animated:YES completion:^{
        
    }];
}


@end
