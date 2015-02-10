//
//  TaskDescriptionViewController.m
//  Coding_iOS
//
//  Created by Ease on 15/1/8.
//  Copyright (c) 2015年 Coding. All rights reserved.
//

#import "TaskDescriptionViewController.h"
#import "Coding_NetAPIManager.h"
#import "WebContentManager.h"
#import "EaseMarkdownTextView.h"

@interface TaskDescriptionViewController ()<UIWebViewDelegate>
@property (strong, nonatomic) UISegmentedControl *segmentedControl;
@property (assign, nonatomic) NSInteger curIndex;

@property (strong, nonatomic) UIWebView *preview;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicator;

@property (strong, nonatomic) EaseMarkdownTextView *editView;
@end

@implementation TaskDescriptionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    if (!_segmentedControl) {
        _segmentedControl = ({
            UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"编辑", @"预览"]];
            [segmentedControl setWidth:80 forSegmentAtIndex:0];
            [segmentedControl setWidth:80 forSegmentAtIndex:1];
            [segmentedControl setTitleTextAttributes:@{
                                                        NSFontAttributeName: [UIFont boldSystemFontOfSize:16],
                                                        NSForegroundColorAttributeName: [UIColor colorWithHexString:@"0x28303b"]
                                                        }
                                             forState:UIControlStateSelected];
            [segmentedControl setTitleTextAttributes:@{
                                                        NSFontAttributeName: [UIFont boldSystemFontOfSize:16],
                                                        NSForegroundColorAttributeName: [UIColor whiteColor]
                                                        } forState:UIControlStateNormal];
            [segmentedControl addTarget:self action:@selector(segmentedControlSelected:) forControlEvents:UIControlEventValueChanged];
            segmentedControl;
        });
        
        self.navigationItem.titleView = _segmentedControl;
    }
    _markdown = _markdown? _markdown : @"";
    self.curIndex = (_markdown.length > 0)? 1: 0;
    
    [self.navigationItem setRightBarButtonItem:[UIBarButtonItem itemWithBtnTitle:@"保存" target:self action:@selector(saveBtnClicked)] animated:YES];
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    [[[[NSNotificationCenter defaultCenter] rac_addObserverForName:UIKeyboardWillChangeFrameNotification object:nil] takeUntil:self.rac_willDeallocSignal] subscribeNext:^(NSNotification *aNotification) {
        if (self.editView) {
            NSDictionary* userInfo = [aNotification userInfo];
            CGRect keyboardEndFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
            self.editView.contentInset = UIEdgeInsetsMake(0, 0, CGRectGetHeight(keyboardEndFrame), 0);
        }
    }];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if (self.curIndex == 0 && self.editView) {
        [self.editView becomeFirstResponder];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)segmentedControlSelected:(id)sender{
    UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
    self.curIndex = segmentedControl.selectedSegmentIndex;
    if (self.curIndex == 0) {
        [_editView becomeFirstResponder];
    }else{
        [_editView resignFirstResponder];
    }
}

- (void)saveBtnClicked{
    NSString *mdStr = self.editView.text;
    @weakify(self);
    [[Coding_NetAPIManager sharedManager] request_MDHtmlStr_WithMDStr:mdStr andBlock:^(id data, NSError *error) {
        @strongify(self);
        if (data) {
            if (self.savedNewMDBlock) {
                self.savedNewMDBlock(self.editView.text, data);
            }
            [self.navigationController popViewControllerAnimated:YES];
        }
    }];
}


- (void)setCurIndex:(NSInteger)curIndex{
    _curIndex = curIndex;
    if (_segmentedControl.selectedSegmentIndex != curIndex) {
        [_segmentedControl setSelectedSegmentIndex:_curIndex];
    }
    
    if (_curIndex == 0) {
        [self loadEditView];
    }else{
        [self loadPreview];
    }
}

- (void)loadEditView{
    if (!_editView) {
        _editView = [[EaseMarkdownTextView alloc] initWithFrame:self.view.bounds];
        _editView.textColor = [UIColor colorWithHexString:@"0x999999"];
        _editView.font = [UIFont systemFontOfSize:16];
        _editView.text = _markdown;
        [self.view addSubview:_editView];
        [_editView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.view);
        }];
        @weakify(self);
        
        [_editView.rac_textSignal subscribeNext:^(NSString *mdStr) {
            @strongify(self);
            self.navigationItem.rightBarButtonItem.enabled = ![mdStr isEqualToString:self.markdown];
        }];
    }
    _editView.hidden = NO;
    _preview.hidden = YES;
    _activityIndicator.hidden = YES;
}

- (void)loadPreview{
    if (!_preview) {
        _preview = [[UIWebView alloc] initWithFrame:self.view.bounds];
        _preview.delegate = self;
        _preview.backgroundColor = [UIColor clearColor];
        _preview.opaque = NO;
        _preview.scalesPageToFit = YES;
        //webview加载指示
        _activityIndicator = [[UIActivityIndicatorView alloc]
                              initWithActivityIndicatorStyle:
                              UIActivityIndicatorViewStyleGray];
        _activityIndicator.hidesWhenStopped = YES;
        [_activityIndicator setCenter:CGPointMake(CGRectGetWidth(_preview.frame)/2, CGRectGetHeight(_preview.frame)/2)];
        [_preview addSubview:_activityIndicator];

        [self.view addSubview:_preview];
        [_preview mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.view);
        }];
    }
    _preview.hidden = NO;
    _activityIndicator.hidden = NO;
    _editView.hidden = YES;
    [self previewLoadMDData];
}

- (void)previewLoadMDData{
    NSString *mdStr = self.editView? self.editView.text : _markdown;
    [_activityIndicator startAnimating];
    
    @weakify(self);
    [[Coding_NetAPIManager sharedManager] request_MDHtmlStr_WithMDStr:mdStr andBlock:^(id data, NSError *error) {
        @strongify(self);
        NSString *htmlStr = data? data : error.description;
        NSString *contentStr = [WebContentManager markdownPatternedWithContent:htmlStr];
        [self.preview loadHTMLString:contentStr baseURL:nil];
    }];
}

#pragma mark UIWebViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
    NSLog(@"strLink=[%@]",request.URL.absoluteString);
    return YES;
}
- (void)webViewDidStartLoad:(UIWebView *)webView{
    [_activityIndicator startAnimating];
}
- (void)webViewDidFinishLoad:(UIWebView *)webView{
    [_activityIndicator stopAnimating];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
    if([error code] == NSURLErrorCancelled)
        return;
    else{
        DebugLog(@"%@", error.description);
        [self showError:error];
    }
}

#pragma mark UITextViewDelegate
- (void)textViewDidChange:(UITextView *)textView{
    
}
@end
