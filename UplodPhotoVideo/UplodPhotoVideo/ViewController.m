//
//  ViewController.m
//  UplodPhotoVideo
//
//  Created by liyang on 16/12/9.
//  Copyright © 2016年 liyang. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "AFNetworking.h"

typedef NS_ENUM(NSUInteger, UpFileType) {
    upFileType_image,
    upFileType_video
};

@interface ViewController ()<UINavigationControllerDelegate,UIImagePickerControllerDelegate>


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}



- (IBAction)takePhoto:(id)sender
{
    UIImagePickerController *pickVc = [[UIImagePickerController alloc] init];
    pickVc.delegate = self;
    pickVc.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
    [self presentViewController:pickVc animated:YES completion:nil];
}

- (IBAction)takeVideo:(id)sender
{
    UIImagePickerController *pickVc = [[UIImagePickerController alloc] init];
    pickVc.delegate = self;
    pickVc.sourceType = UIImagePickerControllerSourceTypeCamera;
    pickVc.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
    pickVc.videoQuality = UIImagePickerControllerQualityTypeMedium; //录像质量
    pickVc.videoMaximumDuration = 600.0f; //录像最长时间
    pickVc.mediaTypes = [NSArray arrayWithObjects:@"public.movie", nil];
    [self presentViewController: pickVc animated:YES completion:nil];
}

- (IBAction)selectVideoOrPhoto:(id)sender
{
    UIImagePickerController *pickVc = [[UIImagePickerController alloc] init];
    pickVc.delegate = self;
    pickVc.sourceType = UIImagePickerControllerSourceTypeCamera;
    [self presentViewController: pickVc animated:YES completion:nil];
}

#pragma mark - UIImagePickerController的代理方法
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    NSString *urlStr = @"https://www.yesingbeijing.com/chat/files/uploadfile";
    
    if ([info[UIImagePickerControllerMediaType] isEqualToString:@"public.movie"]){
        // 视频
        NSURL *videoURL = [info objectForKey:UIImagePickerControllerMediaURL];
        // 获取本地视频url地址
        NSURL *mp4 = [self convertToMp4:videoURL];
        NSData *data = [NSData dataWithContentsOfURL:mp4];
        NSDictionary *param = @{@"filekind":@"userintrovideo", @"filename":@"video"};
        [self UpWithPOST:urlStr parameters:param data:data UpFileType:upFileType_video];
    }else if ([info[UIImagePickerControllerMediaType] isEqualToString:@"public.image"]){
        
        UIImage *img = info[UIImagePickerControllerOriginalImage];
        NSData *data = UIImageJPEGRepresentation(img, 1.0);
        NSDictionary *param = @{@"filekind":@"head", @"filename":@"image"};
        [self UpWithPOST:urlStr parameters:param data:data UpFileType:upFileType_image];
    }
}


- (void)UpWithPOST:(NSString *)URLString
         parameters:(NSDictionary *)parameters
               data:(NSData *)fileData
         UpFileType:(UpFileType)type //后台给图片服务器上起的名字
{
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json",
                                                         @"text/plain",
                                                         @"text/javascript",
                                                         @"text/json",
                                                         @"text/html",
                                                         @"image/jpeg", nil];
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES]; // 开启状态栏动画
    
    NSURLSessionDataTask *uploadTask = [manager POST:URLString parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        
        // 注意点: 当传图片的时候，typeName是image ， mimeType是@"image/*"
        // 注意点: 当传视频的时候，typeName是video ， mimeType是@"video/*"
        // filename一般不能省略后缀，比如jpg 和 mp4
        
        NSString *typeName, *mimeType, *fileName;
        if (type==upFileType_image) {
            typeName = @"image";
            mimeType = @"image/*";
            fileName = @"fileName.jpg";
        }else if (type==upFileType_video) {
            typeName = @"video";
            mimeType = @"video/*";
            fileName = @"fileName.mp4";
        }
        
        [formData appendPartWithFileData:fileData name:typeName fileName:fileName mimeType:mimeType];
        
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        NSLog(@"%lld--%lld",uploadProgress.totalUnitCount, uploadProgress.totalUnitCount);
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        NSLog(@"成功:%@",responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    }];
    [uploadTask resume];
}


// 视频转换为MP4
- (NSURL *)convertToMp4:(NSURL *)movUrl
{
    NSURL *mp4Url = nil;
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:movUrl options:nil];
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avAsset];
    
    if ([compatiblePresets containsObject:AVAssetExportPresetHighestQuality]) {
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc]initWithAsset:avAsset
                                                                              presetName:AVAssetExportPresetHighestQuality];
        NSString *mp4Path = [NSString stringWithFormat:@"%@/%d%d.mp4", [self dataPath], (int)[[NSDate date] timeIntervalSince1970], arc4random() % 100000];
        mp4Url = [NSURL fileURLWithPath:mp4Path];
        exportSession.outputURL = mp4Url;
        exportSession.shouldOptimizeForNetworkUse = YES;
        exportSession.outputFileType = AVFileTypeMPEG4;
        dispatch_semaphore_t wait = dispatch_semaphore_create(0l);
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            switch ([exportSession status]) {
                case AVAssetExportSessionStatusFailed: {
                    NSLog(@"failed, error:%@.", exportSession.error);
                } break;
                case AVAssetExportSessionStatusCancelled: {
                    NSLog(@"cancelled.");
                } break;
                case AVAssetExportSessionStatusCompleted: {
                    NSLog(@"completed.");
                } break;
                default: {
                    NSLog(@"others.");
                } break;
            }
            dispatch_semaphore_signal(wait);
        }];
        long timeout = dispatch_semaphore_wait(wait, DISPATCH_TIME_FOREVER);
        if (timeout) {
            NSLog(@"timeout.");
        }
        if (wait) {
            //dispatch_release(wait);
            wait = nil;
        }
    }
    return mp4Url;
}
- (NSString*)dataPath
{
    NSString *dataPath = [NSString stringWithFormat:@"%@/Library/appdata/chatbuffer", NSHomeDirectory()];
    NSFileManager *fm = [NSFileManager defaultManager];
    if(![fm fileExistsAtPath:dataPath]){
        [fm createDirectoryAtPath:dataPath
      withIntermediateDirectories:YES
                       attributes:nil
                            error:nil];
    }
    return dataPath;
}

@end
