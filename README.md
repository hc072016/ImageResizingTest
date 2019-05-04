# Image Resize and Compression Test
Many people compare a few ways to resize or compress in the app's document directory with a focus on execution time.
I try to find a way to use least amount of memory when resizing and compressing images from the Photos library.
Since images are in Photos library, they must be fetched from the Photos framework. (Or the deprecated Assets Library framework)
Memory spike can easily crash older iOS devices.
Then images can be resized by Photos framework or ImageIO framework and can be compressed by UIKit framework or ImageIO framework.
Result:
ImageIO framework compression is better in terms of memory usage over UIKit.
Surpirsingly there is no clear win amongst the Photos framework and the ImageIO framework.
Many people run different tests on one image, but I found that different images have direct impact on the performance and memory usage.
Image file size and image dimension size have a positive correlation to memory usage, but not always the case.
Two 4k images of roughly same file size. One can make Photos framework a high memory spike, but not ImageIO framework. The other image could have opposite result.
