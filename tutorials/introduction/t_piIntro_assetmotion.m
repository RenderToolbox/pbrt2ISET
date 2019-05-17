%% Tutorial on how to add motion blur of an asset to the scene
%
% Description:
%    This script shows how to add motion blur to individual objects within
%    a scene.
%
% Dependencies:
%    ISET3d, ISETCam
%
% Notes:
%    * Check that you have the updated docker image by running
%       docker pull vistalab/pbrt-v3-spectral
%       docker pull vistalab/pbrt-v3-spectral:test
%
% See Also:
%   t_piIntro_*

% History:
%    XX/XX/19   Z   Zhenyi SCIEN 2019
%    04/22/19  JNM  Documentation pass
%    05/09/19  JNM  Merge with master


%% Initialize ISET and Docker
ieInit;
if ~piDockerExists, piDockerConfig; end

%% Read pbrt files
sceneName = 'simpleScene';

FilePath = fullfile(piRootPath, 'data', 'V3', sceneName);
fname = fullfile(FilePath, [sceneName, '.pbrt']);
if ~exist(fname, 'file'), error('File not found'); end

thisR = piRead(fname);

%% Set render quality
% This is a low resolution for speed.
thisR.set('film resolution', [400 300]);
thisR.set('pixel samples', 128);

%% List material library
% This value determines the number of ray bounces. The scene has glass we
% need to have at least 2 or more.
thisR.integrator.maxdepth.value = 5;

% This is a convenient routine we use when there are many parts and
% you are willing to accept ZL's mapping into materials based on
% automobile parts.
piMaterialGroupAssign(thisR);

%% Write out the pbrt scene file, based on thisR.
thisR.set('fov', 45);

% We have to check what happens when the sceneName is the same as the
% original, but we have added materials. This section here is important to
% clarify for us.
outFile = fullfile(piRootPath, 'local', sceneName, ...
    sprintf('%s.pbrt', sceneName));
thisR.set('outputFile', outFile);

% The first time, we create the materials folder.
piWrite(thisR, 'creatematerials', true);

%{
coordMap = piRender(thisR, 'renderType', 'coordinates'); %, 'reuse', true);
coordMap((coordMap(:, :, 1)== 0) & (coordMap(:, :, 2) == 0) & ...
    (coordMap(:, :, 3) == 0)) = NaN;
x  = coordMap(:, :, 1) - thisR.lookAt.from(1);
y  = coordMap(:, :, 2) - thisR.lookAt.from(2);
z  = coordMap(:, :, 3) - thisR.lookAt.from(3);
player = pcplayer([min(x(:)), nanmax(x(:))], ...
    [min(z(:)), nanmax(z(:))], [min(y(:)), nanmax(y(:))]);
ptCloud = pointCloud([x(:), z(:), y(:)]);
view(player, ptCloud);
%}

%% Render.
% Maybe we should speed this up by only returning radiance.
scene = piRender(thisR, 'render type', 'radiance'); %, 'reuse', true);
sceneWindow(scene);
sceneSet(scene, 'gamma', 0.7);

%% Introduce motion blur
% The motion blur is assigned to a particular asset.  In this example,
% we are moving the third asset, assets(3)
fprintf('Moving asset named: %s\n', thisR.assets(3).name);

% Check current object position
%
% Position is saved as x, y, z;
%  z represents depth.
%  x represents horizontal position
%  y represents vertical position

fprintf('Object position: \n    x: %.1f, depth: %.1f \n', ...
    thisR.assets(3).position(1), thisR.assets(3).position(3));

% To add a motion blur you need to define the shutter speed of the camera.
% This is supposed in the shutter open time and close time. These are
% represented in seconds.

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
% second the object changes 0.1 meters in the x-direction. To make him
% jump, we would change the y-position.
thisR.assets(3).motion.position(1) = thisR.assets(3).position(1) + 0.1;

%% Render the motion blur
piWrite(thisR, 'creatematerials', true);
scene = piRender(thisR, 'render type', 'radiance'); %, 'reuse', true);
scene = sceneSet(scene, 'name', 'motionblur: Translation');
sceneWindow(scene);
sceneSet(scene, 'gamma', 0.7);

%% Add some rotation to the motion
% The rotation matrix is defined as:
%
%    (z    y    x in deg)
%     0    0    0
%     0    0    1
%     0    1    0
%     1    0    0
%
% To rotate around the z-axis, we change (1, 1)
% To rotate around the y-axis, we change (1, 2)
% To rotate around the y-axis, we change (1, 3)
%
% A plus value for rotation is CCW
%
% The rotation is around the center of the asset

% No translation
thisR.assets(3).motion.position = thisR.assets(3).position;

% Rotate 30 deg around the z-axis (depth direction)
thisR.assets(3).motion.rotate(1, 1) = 30;

%% Write and render the motion blur
piWrite(thisR, 'creatematerials', true);
scene = piRender(thisR, 'render type', 'radiance'); %, 'reuse', true);
scene = sceneSet(scene, 'name', 'motionblur: Rotation');
sceneWindow(scene);
sceneSet(scene, 'gamma', 0.7);

%% END
