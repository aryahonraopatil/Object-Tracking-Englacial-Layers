%make layer movie for target tracking
%updated 5/4/23 by R.Williams to make presentable for sharing, handle cases

clear all
close all

%% read the layers array
[layersFilename,loadPath] = uigetfile('*.mat',...
               'Select a LAYERS-Data file');
if layersFilename == 0 
    loadPath = 'Documents/IND_STUDY'; %change this for your machine/data
    baseName = 'Data_20120418_01_042';
    maskPath = fullfile(loadPath,['LAYERS-',baseName,'.mat']);
else
    maskPath = fullfile(loadPath,layersFilename);
end
maskStruct = load(maskPath);
maskLabels = maskStruct.labelayer; %has some breaks in unique label ids, no need to associate?
%debug plots
%{
%labelpng = imread('C:\Users\eikce\Desktop\iHARP\Data_20120418_01_042.png');
%figure;imagesc(labelpng);
%}
uniqueLabels = unique(maskLabels);

% rescale to fit video in memory 
% I invented this but I don't understand it
imageScaleFactor = 0.5;
resizeStrel = strel([0,1,0;0,1,0]);%?? 
maskLabelsOriginal = maskLabels;
maskLabelsResized = imresize(imdilate(maskLabels,resizeStrel),imageScaleFactor,'nearest');
maskLabels = maskLabelsResized;

%clear maskStruct

%% just pick one layer to demo
% find longest layer, get its neighbor?
%layeridxes = [52,94]; %todo - support this

%l1 = 94; %original
l1 = 52; %todo: fix this so it's not hardcoded

layerIsolate = maskLabels; %create a new array to prep for isolating just one layer
layerIsolate(~(maskLabels == l1)) = 0; %set all values not equal to that layer to 0

%get the number of rows and number of columns
[nrows,ncols] = size(maskLabels);

%% make movie frames
addTail=false; %boolean for whether to add the cute tail to the video or not. This is never needed, but always wanted :-)

fprintf('creating frame arrays....')

frame = false(size(maskLabels)); %array to hold the current frame
frames2use = 1:1:ncols;
frameArray = false(size(maskLabels,1),size(maskLabels,2),1,length(frames2use)); %array of arrays to hold all the frames for easier writing but more memory

if addTail
    frame_trail = false(size(maskLabels)); %mask for storing the trail also, just for visualization
    frame_trail_array = false(size(maskLabels,1),size(maskLabels,2),1,length(frames2use));
end

f_idx = 0; %index for skipping frames (not used currently in favor of resizing)
for c = frames2use
    f_idx = f_idx+1;
    frame = false(size(maskLabels));
    target_row = find(layerIsolate(:,c)); %for this column, find the layer's row number
    
    if ~isempty(target_row) %if there is a row number, the layer exists at the column
        frame(target_row,f_idx) = true; %add that row, and only that row, to the frame
        if addTail
            frame_trail(target_row,f_idx) = true; %add that row and all previous rows to the tail frame
        end
    end
    frameArray(:,:,1,f_idx) = frame; %add to the collection of frame arrays
    if addTail
        frame_trail_array(:,:,1,f_idx) = frame_trail;%add to the collection of frame arrays with tail
    end

end
fprintf('done creating frame arrays\n')

%% process movie frames of "detect"

fprintf('morphing target...')
%define the single pixel target modifications
targetMorph={'rect'; [10,10]};
extractBboxes = true;

%create empty array for morphed frames
frameArray_morph = false(size(frameArray));

tic
%keep both the current scaled bounding box, which matches the movie,
%and what wold be the original bounding box values, which match the radar image
target_bbox = struct('frame',[],'bbox',[],'bbox_original',[]);

for ii = 1:size(frameArray,4)
    %dilate the target in each frame and save as new array
    dilatedBW = imdilate(frameArray(:,:,1,ii), strel(targetMorph{:})); 
    frameArray_morph(:,:,1,ii) = dilatedBW;
    if extractBboxes
        target_bbox(ii).frame = ii;
        cc = regionprops(dilatedBW,'BoundingBox');
        if ~isempty(cc)
            
            %debug plots
            %{
            J = mat2gray(maskLabels);
            J = insertObjectAnnotation(J,'Rectangle',ceil(cc.BoundingBox),'thebox');
            %}
            
            target_bbox(ii).bbox = ceil(cc.BoundingBox);
            if imageScaleFactor ~= 1
                target_bbox(ii).bbox_original = bboxresize(target_bbox(ii).bbox,1/imageScaleFactor);
            end
            
            %debug plots
            %{
            J2 = mat2gray(maskLabelsOriginal);
            J2 = insertObjectAnnotation(J2,'Rectangle',bboxresize(ceil(cc.BoundingBox),1/imageScaleFactor),'thebox');
            figure;imshow(J2)
            %}
        end
    end
end
fprintf('done morphing target\n')
toc



%% process movie frames of "tail"
if addTail
    fprintf('processing tail...')
    tailLength = 100;
    det_and_tail = uint8(zeros(size(frame_trail_array)));
    for ii = tailLength+1:size(frameArray,4)
        
        col_vec = zeros(size(frameArray,2),1);
        col_vec(ii-tailLength:ii) = single(linspace(0,1, tailLength+1));
        
        frameArray_tail_fade = frame_trail_array(:,:,1,ii).*col_vec';
        both = single(frameArray_tail_fade+frameArray_morph(:,:,1,ii));
        both(both >1) = 1;
        det_and_tail(:,:,1,ii) = uint8(255.*both);
    end
    fprintf('done processing tail\n')
end

%% write the frames to video
scaledAmtStr = ['_',num2str(imageScaleFactor*100),'pct'];%convert image scaling to usable string
baseName = 'Data_20120418_01_042';
if addTail
    vidName = [baseName,'_layer',num2str(l1),'_',...
        targetMorph{1},num2str(targetMorph{2}(1)),...
        scaledAmtStr,...
        '_wTail',...
        ];
else
    vidName = [baseName,'_layer',num2str(l1),'_',...
        targetMorph{1},num2str(targetMorph{2}(1)),...
        scaledAmtStr,...
        ];
end
vidObj = VideoWriter([vidName,'.mp4'],'MPEG-4');
open(vidObj);
tic
fprintf('writing frame array to video')

if addTail
    writeVideo(vidObj,det_and_tail);
else
    writeVideo(vidObj,uint8(255.*frameArray_morph)); %convert to grayscale image values
end

close(vidObj);
fprintf('done writing %s\n', vidName);
toc

%%

