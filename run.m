%% Label3D RUNTIME

clear all;
close all;
addpath(genpath('deps'))
addpath(genpath('skeletons'))
%danncePath = 'D:\Project\sdannce\';

%% Setting time! SET THESE BEFORE YOU DO ANYTHING!!!

projectFolder = fullfile('D:\Project\SDANNCE-Models\4CAM-250620\SD-20250705-MULTI\');

framesToLabel = 1:30:5000; % Only used when isInitialLabeling
numViews = 4; % Only used when isInitialLabeling

ChosenOne = '';

isInitialLabeling = 0;
isLoadingImplant = 0;
isExporting = 1;
isCOM = 1;
isMulti = 1;
isChosenOne = 0;

%% Get the skeleton

if isMulti == 0
    if isCOM == 1
        skeleton = load('com');
    else
        skeleton = load('skeletons/rat16');
    end
else
    if isCOM == 1
        skeleton = load('ncom-multi.mat');
    end
end

%% Load previous labelled data

if isInitialLabeling == 0
    if isLoadingImplant == 1
        labelled_data = "viewer-implanted.mat";
    else
        if isChosenOne == 1
            labelled_data = ChosenOne;
        else
            dataDir = '.';
            matFiles = dir(fullfile(dataDir, '*_Label3D.mat'));
            if isempty(matFiles)
                error('No .mat files with the pattern *_Label3D.mat found in the specified directory.');
            end

            fileDates = NaT(length(matFiles), 1);
            filenameFormat = 'yyyyMMdd_HHmmss';

            for i = 1:length(matFiles)
                fileName = matFiles(i).name;
                try
                    underscoreIdx = strfind(fileName, '_');
                    if length(underscoreIdx) >= 2
                        dateTimeStr = fileName(1 : underscoreIdx(2)-1);
                        fileDates(i) = datetime(dateTimeStr, 'InputFormat', filenameFormat);
                    else
                        warning(['Could not parse date from filename: ', fileName]);
                    end
                catch ME
                    warning(['Error parsing date from filename: ', fileName, ' - ', ME.message]);
                    fileDates(i) = NaT;
                end
            end
            [~, newestIdx] = max(fileDates);
            newestFileName = fullfile(dataDir, matFiles(newestIdx).name);
            labelled_data = newestFileName;
        end
    end
    if isCOM == 0
    framesToLabel = matfile(labelled_data).framesToLabel;
    end
end

%% Load the videos into memory

vidName = '0.mp4';
vidPaths = collectVideoPaths(projectFolder,vidName);
videos = cell(4,1);
sync = collectSyncPaths(projectFolder, '*.mat');
sync = cellfun(@(X) {load(X)}, sync);

calibPaths = collectCalibrationPaths(projectFolder);
params = cellfun(@(X) {load(X)}, calibPaths);

if isInitialLabeling == 1
    numCam = numViews;
else
    numCam = length(matfile(labelled_data).camParams);
end

if isempty(sync)
    dannce_file = dir(fullfile(projectFolder, '*dannce.mat'));
    if numCam == 5
        dannce_file = dir(fullfile(projectFolder, '*dannce_5cam.mat'));
    end
    dannce = load(fullfile(projectFolder, dannce_file(1).name));
    sync = dannce.sync;
    %params = dannce.params;
end

totalFrames = length(framesToLabel);

for nVid = 1:numel(vidPaths)
    frameInds = sync{nVid}.data_frame(framesToLabel);
    videos{nVid} = readFrames(vidPaths{nVid}, frameInds+1);
end

%% Start Label3D

close all
if isInitialLabeling == 1
    labelGui = Label3D(params, videos, skeleton);
    labelGui.plotCameras
else
    labelGui = Label3D(labelled_data, videos);
    if isExporting == 1
        lb = matfile(labelled_data, 'Writable', false);
        if any(isnan(lb.data_3D),'all')
            [NaN_rows, NaN_columns] = find(isnan(lb.data_3D));
            disp('There are still frames not completely labelled:');
            disp(unique(NaN_rows));
        else
            labelGui.status = 2*ones(length(skeleton.joint_names),nVid,totalFrames);
            labelGui.sync = sync;
            labelGui.exportDannce('saveFolder', projectFolder, "framesToLabel", framesToLabel, "totalFrames", totalFrames)
        end
    end
end