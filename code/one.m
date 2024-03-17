% Set up VideoWriter object
vidObj = VideoWriter('mylayer.avi');
vidObj.FrameRate = 30;
open(vidObj);

% Load image from .mat file
imgStruct = load('LAYERS-Data_20120516_01_090.mat');
img = imgStruct.imlayer; 

% Choose a layer to test
layerIdx = 3;

% Write image to video
writeVideo(vidObj, img);

% Close VideoWriter object
close(vidObj);