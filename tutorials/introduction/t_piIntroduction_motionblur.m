%% Add motion blur to the scene
%
% This script shows how to add motion blur to individual objects in
% the scene.
%
% Dependencies:
%
%    ISET3d, ISETCam 
%
%  Check that you have the updated docker image by running
%
%    docker pull vistalab/pbrt-v3-spectral
%
% Zhenyi SCIEN 2019
%
% See also
%   t_piIntroduction*

%% Initialize ISET and Docker

ieInit;
if ~piDockerExists, piDockerConfig; end

%% Read pbrt files

FilePath = fullfile(piRootPath,'data','V3','SimpleScene');
fname = fullfile(FilePath,'SimpleScene.pbrt');
if ~exist(fname,'file'), error('File not found'); end

thisR = piRead(fname);

%% Set render quality

% This is a low resolution for speed.
thisR.set('film resolution',[400 300]);
thisR.set('pixel samples',32);

%% List material library

% This value determines the number of ray bounces.  The scene has
% glass we need to have at least 2 or more.  We start with only 1
% bounce, so it will not appear like glass or mirror.
thisR.integrator.maxdepth.value = 5;

% This adds a mirror and other materials that are used in driving
% simulation.
piMaterialGroupAssign(thisR);

%% Write out the pbrt scene file, based on thisR.
thisR.set('fov',45);

% We have to check what happens when the sceneName is the same as the
% original, but we have added materials.  This section here is
% important to clarify for us.
sceneName = 'simpleTest';
outFile = fullfile(piRootPath,'local',sceneName,sprintf('%s_scene.pbrt',sceneName));
thisR.set('outputFile',outFile);

% The first time, we create the materials folder.
piWrite(thisR,'creatematerials',true);

%% Render.  

% Maybe we should speed this up by only returning radiance.
scene = piRender(thisR, 'render type', 'radiance');
sceneWindow(scene);

%% Motion blur from camera
thisR.camera.motion.activeTransformStart.pos   = thisR.assets(2).position;
thisR.camera.motion.activeTransformStart.rotate = thisR.assets(2).rotate;
thisR.camera.motion.activeTransformEnd.pos     = thisR.assets(2).position;
thisR.camera.motion.activeTransformEnd.rotate = thisR.assets(2).rotate;

thisR.camera.motion.activeTransformEnd.pos(3) = thisR.assets(2).position(3)+0.7;
piWrite(thisR,'creatematerials',true);
scene = piRender(thisR, 'render type', 'radiance');
scene = sceneSet(scene,'name','Camera Motionblur: Translation');
sceneWindow(scene);
%% Introduce motion blur

% The motion blur is assigned to a particular asset.  In this example,
% we are moving the third asset, assets(3)
fprintf('Moving asset named: %s\n',thisR.assets(3).name);

% Check current object position
%
% Position is saved as x,y,z; 
%  z represents depth. 
%  x represents horizontal position
%  y represents vertical position

fprintf('Object position: \n    x: %.1f, depth: %.1f \n', ...
    thisR.assets(3).position(1), ...
    thisR.assets(3).position(3));

% To add a motion blur you need to define the shutter speed of the
% camera. This is supposed in the shutter open time and close time.
% These are represented in seconds.

% Open at time zero
thisR.camera.shutteropen.type = 'float';
thisR.camera.shutteropen.value = 0;  

% Close in half a second
thisR.camera.shutterclose.type = 'float';
thisR.camera.shutterclose.value = 0.5;

% Copy the asset position and rotation into the motion slot.
thisR.assets(3).motion.position = thisR.assets(3).position;
thisR.assets(3).motion.rotate   = thisR.assets(3).rotate;

% We will change the position, but not the rotation.  The change in
% position is during the shutter open period.  In this case, in half a
% second the object changes 0.1 meters in the x-direction.  To make
% him jump, we would change the y-position.
thisR.assets(3).motion.position(1) = thisR.assets(3).position(1) + 0.1;

%% Render the motion blur

piWrite(thisR,'creatematerials',true);
scene = piRender(thisR, 'render type', 'radiance');
scene = sceneSet(scene,'name','motionblur: Translation');
sceneWindow(scene);

%% Add some rotation to the motion

% The rotation matrix is defined as: 
%
%    (z    y    x in deg)
%     0    0    0
%     0    0    1
%     0    1    0
%     1    0    0 
%
% To rotate around the z-axis, we change (1,1)
% To rotate around the y-axis, we change (1,2)
% To rotate around the y-axis, we change (1,3)
% 
% A plus value for rotation is CCW
%
% The rotation is around the center of the asset

% No translation
thisR.assets(3).motion.position = thisR.assets(3).position;

% Rotate 30 deg around the z-axis (depth direction)
thisR.assets(3).motion.rotate(1,1) = 30;

% Render the motion blur
piWrite(thisR,'creatematerials',true);
scene = piRender(thisR, 'render type', 'radiance');
scene = sceneSet(scene,'name','motionblur: Rotation');
sceneWindow(scene);

%% END







