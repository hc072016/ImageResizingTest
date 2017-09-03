//
//  ViewController.h
//  ImageResizingTest
//
//  Created by Howie C on 8/19/17.
//  Copyright © 2017 Howie C. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController<UIImagePickerControllerDelegate, UINavigationControllerDelegate>


@property (weak, nonatomic) IBOutlet UIImageView *imageView;


- (IBAction)pickAnImage:(UIButton *)sender;


@end

