%% Process 360 optical images generated by s_360CameraRig.m
% optical image --> sensor --> image processing --> RGB images -->
% stitching code

%% Initialize
ieInit;

workingDir = fullfile('/Users/trishalian/RenderedData/360Renders','whiteRoom2048');
dataDirectory = fullfile(workingDir,'OI');

outputDirectory = fullfile(workingDir,'rgb'); 
if(~exist(outputDirectory,'dir'))
    mkdir(outputDirectory);
end 

%% Get scale factor to remove vignetting

removeVignetting = 1;

% Wide-angle
if(removeVignetting)
    wideAngleWhiteFile = fullfile(workingDir,'wideAngleWhiteScene.mat');
    if(exist(wideAngleWhiteFile,'file'))
        whiteSceneOI = load(wideAngleWhiteFile);
        whiteSceneOI = whiteSceneOI.oi;
        whiteScenePhotons = oiGet(whiteSceneOI,'photons');
        % whiteLevel = oiGet(whiteSceneOI,'illuminance');
        
        % Note we're getting some weird color artifacts near the edge of the
        % white scene. I still need to debug this. But in the meantime, let's
        % just use a middle wavelength.
        nWaves = oiGet(whiteSceneOI,'nWaves');
        whiteLevel = whiteScenePhotons(:,:,round(nWaves/2));
        vignetteScale = 1./(whiteLevel./max(whiteLevel(:)));
        
        % Note: Rings are a consequence of the pupil sampling method used in PBRTv3.
        % figure; imagesc(vignetteScale); colorbar;
    else
        vignetteScale = 1;
    end
end
      
%% Loop through all images

dirInfo = dir(fullfile(dataDirectory,'*.mat'));
nFiles = length(dirInfo);

originAll = [];
targetAll = [];
upAll = [];
indicesAll = [];

% Read first file to determine photon scale factor


for ii = 1:nFiles
    
    clear oi;
    
    % Load current optical image
    load(fullfile(dataDirectory,dirInfo(ii).name));
    
    % --- Setup OI ---
    
    % Instead of adjusting illuminance for each image, we scale the number
    % of photons by the same factor for all images on the rig. This keeps
    % the scale across images on the rig relative. You may have to play
    % with the scale depending on the scene. 
    scale = 1e13; % This creates an mean illuminance of roughly 50 lux for cam1 for the whiteRoom
    %scale = 1e11; % for livingroom
    photons = scale.*oiGet(oi,'photons');
    oi = oiSet(oi,'photons',photons);
    
    % It's helpful at this point to check the dimensions of the OI given in the
    % window. Are they reasonable? If not, it's possible the focal length,
    % aperture diameter, and FOV were not set correctly when saving the OI.
   
    % --- Setup sensor ---
    
    sensor = sensorCreate();
    
    % Set the pixel size
    % Sensor size will be the same as the size of the optical image. 
    %sensorPixelSize = 5.5 *10^-6; % From Grasshopper
    sensorPixelSize = oiGet(oi,'sample spacing','m');
    oiHeight = oiGet(oi,'height');
    oiWidth = oiGet(oi,'width');
    sensorSize = round([oiHeight oiWidth]./sensorPixelSize);
    sensor = sensorSet(sensor,'size',sensorSize);
    sensor = sensorSet(sensor,'pixel size same fill factor',sensorPixelSize);
    
    % Set exposure time
    sensor = sensorSet(sensor,'exp time',1/600); % in seconds (for whiteRoom)
    %sensor = sensorSet(sensor,'exp time',1/1000); % in seconds (for livingRoom)
    %sensor = sensorSet(sensor,'auto Exposure',true);

    % Compute!
    sensor = sensorCompute(sensor,oi);
    
    % Check exposure
    exposureTime = sensorGet(sensor,'exp time');
    fprintf('Exposure Time is 1/%0.2f s \n',1/exposureTime);
    
%     vcAddObject(sensor); 
%     sensorWindow;

    % --- Setup Image Processing ---
    ip = ipCreate;
    ip = ipSet(ip,'demosaic method','bilinear');
    ip = ipSet(ip,'correction method illuminant','gray world');
    
    % Compute!
    ip = ipCompute(ip,sensor);
    
    if(removeVignetting)
        % Scale according to the white image (remove vignetting)
        % Is there anything built in to ISET to do this?
        if(strcmp(dirInfo(ii).name,'cam0.dat') || ...
                strcmp(dirInfo(ii).name,'cam15.dat') || ...
                strcmp(dirInfo(ii).name,'cam16.dat'))
            % Fish eye lens
        else
            % Wide-angle
            ip.data.result = ip.data.result.*vignetteScale;
        end
    end
    
    vcAddObject(ip);
    ipWindow;
    
    % --- Save Images ---
    
    % Flip the indexing. The cameras should run clockwise, but from PBRT
    % they run counter clockwise. I think this is due to some coordinate
    % axes flips.
    
    allIndices = [0 circshift(14:-1:1,1) 15 16];
    expression = '(\d+)';
    matchStr = regexp(dirInfo(ii).name,expression,'match');
    currIndex = str2double(cell2mat(matchStr));
    newIndex = allIndices(currIndex+1);
    
%     expression = '(\d+)';
%     matchStr = regexp(dirInfo(ii).name,expression,'match');
%     currIndex = str2double(cell2mat(matchStr));
%     newIndex = currIndex;
    
    % Save the images according to the Surround360 format
    srgb = ipGet(ip,'data srgb');
    
    % Crop the image
%     [M,N,C] = size(srgb);
%     center = round([M/2,N/2]);
%     removeX = 30;
%     removeY = round(removeX*(M/N));
%     srgb = srgb(removeY:(2*center(1)-removeY),removeX:(2*center(2)-removeX),:);
    
    imageDir = fullfile(outputDirectory,sprintf('cam%d',newIndex));
    if(~exist(imageDir,'dir'))
        mkdir(imageDir);
    end
    imwrite(srgb,fullfile(imageDir,'000000.png'))
    
    
    % We will save the origins/targets etc. according to the new index.
    % This is helpful when we try to match up with the camera_rig.json
    % file.
    %{
    originAll = [originAll; origin];
    targetAll = [targetAll; target];
    upAll = [upAll; up];  
    indicesAll = [indicesAll; newIndex];
    %}
end


%% Output a json geometry rig file
%{
% Save camera rig geometry info
% Maybe we should write this in a text file. 
save(fullfile(outputDirectory,'cameraRigGeometry.mat'),'originAll','targetAll','upAll','indicesAll','rigOrigin');

% Subtract rig origin
originAll = originAll - rigOrigin;
targetAll = targetAll - rigOrigin;

% Scale to cm
originAll = originAll.*10^2;
targetAll = targetAll.*10^2;
upAll = upAll.*10^2;

% Some calculations
upAll = upAll./sqrt(sum(upAll.^2,2));
forwardAll = targetAll - originAll;
forwardAll = forwardAll./sqrt(sum(forwardAll.^2,2));

rightAll = zeros(size(forwardAll));
for ii = 1:length(forwardAll)
    rightAll(ii,:) = cross(forwardAll(ii,:),upAll(ii,:));
end
rightAll = rightAll./sqrt(sum(rightAll.^2,2));

% Plot
figure(10);clf; hold on; grid on;
xlabel('x'); ylabel('y'); zlabel('z');

s = 10;
for ii = 1:length(indicesAll)
    

    quiver3(originAll(ii,1),originAll(ii,2),originAll(ii,3), ...
        upAll(ii,1),upAll(ii,2),upAll(ii,3),s,'b');

    quiver3(originAll(ii,1),originAll(ii,2),originAll(ii,3), ...
        forwardAll(ii,1),forwardAll(ii,2),forwardAll(ii,3),s,'g');

    quiver3(originAll(ii,1),originAll(ii,2),originAll(ii,3), ...
        rightAll(ii,1),rightAll(ii,2),rightAll(ii,3),s,'r');

    plot3(originAll(ii,1),originAll(ii,2),originAll(ii,3),'rx');
    text(originAll(ii,1)+0.01,originAll(ii,2)+0.01,originAll(ii,3)+0.01,num2str(indicesAll(ii)));
    
end

% Read in the default rig and change to match above values
rig = jsonread('/Users/trishalian/GitRepos/Surround360/surround360_render/res/config/camera_rig.json');

for ii = 1:length(rig.cameras)
    currCam = rig.cameras{ii};
    currID = currCam.id;
    id = double(cell2mat(textscan(currID,'cam%d')));
    indexMatch = find(indicesAll == id);
    currCam.origin = originAll(indexMatch,:);
    currCam.up = upAll(indexMatch,:);
    currCam.forward = forwardAll(indexMatch,:);
    currCam.right = rightAll(indexMatch,:);
    rig.cameras{ii} = currCam;
end

opts = struct('indent',' ');
jsonwrite(fullfile(workingDir,'camera_rig_initial.json'),rig,opts);
%}