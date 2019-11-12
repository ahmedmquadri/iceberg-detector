clear all
close all

% Read and intensity stretch input images

% Panchromatic Band
i1 = imread('B8Crop.tif');
adjPanchroImage = imadjust(i1);
outputImage = adjPanchroImage;

% Thermal Band
i2 = imread('B11Crop.tif');
i2c = imadjust(i2);

% Cloud Confidence Band
i3 = imread('BQACrop.tif');
i3c = imadjust(i3);


%% Filter Land Using Thermal Imagery

%Canny edge detection on thermal image
edgeTest = edge(i2c,'Canny');

% Dilate image with a disk-shaped structuring element of radius 3
SE = strel('disk',3);
dilated = imdilate(edgeTest,SE);

% Invert binary image to create a mask of all land mass in the image
inverted = 1 - dilated;

% Remove bodies of water below specified size
thermalMask = bwareaopen(inverted, 50000);

% Create a mask of clouds in the image
cloudMask = bitget(i3,5,'uint16');
cloudMask  = cloudMask>0;

CirrusMask = bitget(i3,13,'uint16');
CirrusMask  = CirrusMask>0;

% figure;
% imshowpair(cloudMask,CirrusMask,'Montage');


cloudMask = cloudMask+CirrusMask; 
cloudMask = cloudMask > 0;

oldCloudMask = i3>4000;

% figure;
% imshowpair(cloudMask,oldCloudMask,'Montage');

% figure;
% imshow(i3);

% Resize masks to match higher resolution band-8 image 
newSize = size(adjPanchroImage);
thermalMask = imresize(thermalMask,newSize);
cloudMask = imresize(cloudMask,newSize);

[x,y] = size(adjPanchroImage);
for i = 1:x    
    for j = 1:y       
        if thermalMask(i,j) == 0
            adjPanchroImage(i,j) = 0;
        elseif cloudMask(i,j) == 1
            adjPanchroImage(i,j) = 0;
        end
    end
end


%% Iceberg Identification

% Create a mask of high intensity pixels
iceBergMask = adjPanchroImage > 55000;

% Remove objects below specified size
iceBergMask = bwareaopen(iceBergMask, 3);

%Remove objects above specified sie
iceBergMask = iceBergMask - bwareaopen(iceBergMask, 500);

% Create a circle around all identified icebergs
SE2 = strel('disk',25);
IDMask = imdilate(iceBergMask,SE2);

% Trace boundaries of Expanded Icebergs
IDMask = edge(IDMask);
SE3 = strel('disk',5);
IDMask = imdilate(IDMask,SE3);

% colorImage = cat(3, Red, Green, Blue);
colorImage = cat(3, outputImage, outputImage, outputImage);

[x,y] = size(outputImage);
for i = 1:x    
    for j = 1:y       
        if IDMask(i,j) == 1
            colorImage(i,j,:) = [65500,0,0];
        end
    end
end

% Zero-Pad Images
nRows = floor(size(iceBergMask,1)/32);
nCols = floor(size(iceBergMask,2)/32);
iceBergMask = padarray(iceBergMask,[nRows nCols],0);

nRows = floor(size(colorImage,1)/32);
nCols = floor(size(colorImage,2)/32);
colorImage = padarray(colorImage,[nRows nCols],0);

% Classify Icebergs
cc = bwconncomp(iceBergMask);
stats = regionprops(cc,'Area','Centroid');
numBergs = size(stats);

for i = 1:numBergs(1)
    
    condition = sqrt(stats(i).Area);
    class = '';
    
    switch true
        case le(condition,4)
            class = 'Small Berg';
        case le(condition,8)
            class = 'Medium Berg';
        case le(condition,13)
            class = 'Large Berg';
        case condition > 13
            class = 'Very Large Berg';
    end
    
    textLocation = [stats(i).Centroid(1)- 260,stats(i).Centroid(2)];
    colorImage = insertText(colorImage,textLocation,class,'FontSize',36,'BoxColor','Red','TextColor', 'White');
end

% Zero-pad the input image to match sie of the output
nRows = floor(size(i1,1)/32);
nCols = floor(size(i1,2)/32);
i1 = padarray(i1,[nRows nCols],0);

% Display initial and final images
figure;
imshowpair(i1, colorImage, 'montage');
title('Original Image vs. Enhanced Image with Icebergs Identified and Classified');