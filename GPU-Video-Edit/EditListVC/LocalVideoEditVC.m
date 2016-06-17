//
//  LocalVideoEditVC.m
//  GPU-Video-Edit
//
//  Created by xiaoke_mh on 16/4/13.
//  Copyright © 2016年 m-h. All rights reserved.
//

#import "LocalVideoEditVC.h"
#import "FilterChooseView.h"


#define FilterViewHeight 95

@interface LocalVideoEditVC ()<UIAlertViewDelegate>
{
//    UIButton * _chooseBtn;
//    UIButton * _chooseFilterBtn;
    UIButton * _filterBegin;
    
    NSURL * _videoUrl;
    
    GPUImageView *filterView;//预览层 view

}
@end

@implementation LocalVideoEditVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor  blackColor];
    UIBarButtonItem * rightItem = [[UIBarButtonItem alloc] initWithTitle:@"Select Video" style:UIBarButtonItemStylePlain target:self action:@selector(choose_click)];
    self.navigationItem.rightBarButtonItem = rightItem;
    

    
    [self choose_click];

    _filterBegin = [UIButton buttonWithType:0];
    _filterBegin.backgroundColor = [UIColor whiteColor];
    _filterBegin.frame = CGRectMake(0, 0, self.view.frame.size.width/3-20, 40);
    _filterBegin.center = CGPointMake(self.view.frame.size.width/2, self.view.frame.size.height-30);
    _filterBegin.layer.cornerRadius = 10;
    _filterBegin.clipsToBounds = YES;
    _filterBegin.layer.masksToBounds = YES;
    _filterBegin.layer.borderWidth = 2;
    _filterBegin.layer.borderColor = [UIColor orangeColor].CGColor;
    [_filterBegin setTitleColor:[UIColor blackColor] forState:0];
    [_filterBegin setTitle:@"Start Synthesis" forState:0];
    [_filterBegin addTarget:self action:@selector(filterBegin_click) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_filterBegin];

    
    filterView = [[GPUImageView alloc] initWithFrame:CGRectMake(0, self.navigationController.navigationBar.bounds.size.height+20, self.view.frame.size.width, self.view.frame.size.height-(self.navigationController.navigationBar.bounds.size.height+20)-60-FilterViewHeight)];
    filterView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:filterView];
    
    FilterChooseView * chooseView = [[FilterChooseView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(filterView.frame), self.view.frame.size.width, FilterViewHeight)];
    chooseView.backback = ^(GPUImageOutput<GPUImageInput> * filter){
        [self choose_callBack:filter];
    };
    [self.view addSubview:chooseView];
}
#pragma mark Select a filter
-(void)choose_callBack:(GPUImageOutput<GPUImageInput> *)filter
{
    pixellateFilter = filter;
    if (!_videoUrl) {
        return;
    }
    [movieFile cancelProcessing];
    [movieFile removeAllTargets];
    movieFile = [[GPUImageMovie alloc] initWithURL:_videoUrl];
    
    [movieFile addTarget:pixellateFilter];
    [pixellateFilter addTarget:filterView];
    [movieFile startProcessing];
}
-(void)showVideoWith:(NSURL *)videourl
{
    [movieFile cancelProcessing];
    movieFile = [[GPUImageMovie alloc] initWithURL:videourl];
        if (pixellateFilter) {
            [movieFile addTarget:pixellateFilter];
            [pixellateFilter addTarget:filterView];
        }else
        {
            [movieFile addTarget:filterView];
        }
    [movieFile startProcessing];
}
#pragma mark 开始合成视频
-(void)filterBegin_click
{
    [MBProgressHUD showMessage:@"Processing"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
       
        NSString *fileName = [@"Documents/" stringByAppendingFormat:@"Movie%d.m4v",(int)[[NSDate date] timeIntervalSince1970]];
        pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:fileName];
        NSURL *movieURL = [NSURL fileURLWithPath:pathToMovie];
        
        AVURLAsset * asss = [AVURLAsset URLAssetWithURL:_videoUrl options:nil];
        CGSize videoSize2 = asss.naturalSize;
        NSLog(@"%f    %f",videoSize2.width,videoSize2.height);

        movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:videoSize2];
        [pixellateFilter addTarget:movieWriter];
        
        movieWriter.shouldPassthroughAudio = YES;
        //    movieFile.audioEncodingTarget = movieWriter;
        [movieFile enableSynchronizedEncodingUsingMovieWriter:movieWriter];
        [movieWriter startRecording];
        
        __weak LocalVideoEditVC * weakSelf = self;
        __weak GPUImageOutput<GPUImageInput> * weakpixellateFilter = pixellateFilter;
        __weak GPUImageMovieWriter * weakmovieWriter = movieWriter;
        [movieWriter setCompletionBlock:^{
            NSLog(@"End video compositing");
            dispatch_async(dispatch_get_main_queue(), ^{
                [MBProgressHUD hideHUD];
                [MBProgressHUD showSuccess:@"The process ends"];
                
                UIAlertView * alertview = [[UIAlertView alloc] initWithTitle:@"save to album" message:nil delegate:weakSelf cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
                [alertview show];
            });
            [weakpixellateFilter removeTarget:weakmovieWriter];
            [weakmovieWriter finishRecording];
        }];
        
    });
}
-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        NSLog(@"baocun");
        [self save_to_photosAlbum:pathToMovie];
    }
}
-(void)save_to_photosAlbum:(NSString *)path
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
            
            UISaveVideoAtPathToSavedPhotosAlbum(path, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
        }
    });

}
-(void)choose_click
{
    UIAlertController *alertVc = [UIAlertController alertControllerWithTitle:@"Select video source" message:@"Choose a video" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cameraAction = [UIAlertAction actionWithTitle:@"Shooting from the camera" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self selectImageFromCamera];
        NSLog(@"Select video camera");
        
    }];
    UIAlertAction *photoAction = [UIAlertAction actionWithTitle:@"Select from album" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self selectImageFromAlbum];
        NSLog(@"Select albums.");
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [alertVc addAction:cameraAction];
    [alertVc addAction:photoAction];
    [alertVc addAction:cancelAction];
    [self presentViewController:alertVc animated:YES completion:nil];
    
}
-(void)selectImageFromCamera
{
    //NSLog(@"camera");
    UIImagePickerController * _imagePickerController = [[UIImagePickerController alloc] init];
    _imagePickerController.delegate = self;
    _imagePickerController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    _imagePickerController.allowsEditing = YES;
    _imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    //Recording video length, default10s
    _imagePickerController.videoMaximumDuration = MAXFLOAT;
    //Camera type (photos, video ...)
    _imagePickerController.mediaTypes = @[(NSString *)kUTTypeMovie,(NSString *)kUTTypeImage];
    //Upload video quality
    _imagePickerController.videoQuality = UIImagePickerControllerQualityTypeHigh;
    //Setting the camera mode (take pictures, record video)
    _imagePickerController.cameraCaptureMode = UIImagePickerControllerCameraCaptureModeVideo;
    
    [self presentViewController:_imagePickerController animated:YES completion:nil];
    
}
-(void)selectImageFromAlbum
{
    ZYQAssetPickerController *picker = [[ZYQAssetPickerController alloc] init];
    picker.maximumNumberOfSelection = 1;//Select only one video
    picker.assetsFilter = [ALAssetsFilter allVideos];
    picker.showEmptyGroups=NO;
    picker.delegate=self;
    picker.selectionFilter = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        if ([[(ALAsset*)evaluatedObject valueForProperty:ALAssetPropertyType] isEqual:ALAssetTypeVideo]) {
            NSTimeInterval duration = [[(ALAsset*)evaluatedObject valueForProperty:ALAssetPropertyDuration] doubleValue];
            return duration >= 5;
        } else {
            return YES;
        }
    }];
    
    [self presentViewController:picker animated:YES completion:NULL];
}
#pragma mark - ZYQAssetPickerController Delegate
-(void)assetPickerController:(ZYQAssetPickerController *)picker didFinishPickingAssets:(NSArray *)assets{
    
    for (int i=0; i<assets.count; i++) {
        NSLog(@"%@",assets[i]);
        ALAsset * asset = assets[i];
        NSURL * url = asset.defaultRepresentation.url;
        _videoUrl = url;
    }
    if (_videoUrl) {
        [self showVideoWith:_videoUrl];

    }
}
#pragma mark UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    NSString *mediaType=[info objectForKey:UIImagePickerControllerMediaType];
    
    if ([mediaType isEqualToString:(NSString *)kUTTypeImage]){
        
    }else{
        //If the video
        NSURL *url = info[UIImagePickerControllerMediaURL];
        _videoUrl = url;
        //Save the video to the album (asynchronous thread)
        NSString *urlStr = [url path];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(urlStr)) {
                
                UISaveVideoAtPathToSavedPhotosAlbum(urlStr, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
            }
        });
    }
    [self dismissViewControllerAnimated:YES completion:^{
        [self showVideoWith:_videoUrl];
    }];
}
#pragma mark 视频保存完毕的回调
- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextIn {
    if (error) {
        NSLog(@"Save Video during error, the error message:%@",error.localizedDescription);
    }else{
        NSLog(@"Video is saved successfully.");
        [MBProgressHUD showSuccess:@"Video saved successfully"];

    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
