%% Draft script
%
% Find a session and acquisition in Flywheel with rendered images
%
% Download the rendered data (from PBRT) and assemble them into an ISETCam
% IP with the metadata
%

%% Set a session and acquisition

% Before too long we will loop over these.  For now, just one at a time.
sessionName = 'city3_09:55_v7.3_f65.43left_o270.00_2019626165416';
acquisitionName = 'pos_50_50_0';

%%  Download and build up the OI
lu = sprintf('wandell/Graphics camera array/renderings/%s/%s',sessionName,acquisitionName);
acquisition = st.lookup(lu);
oi = piAcquisition2ISET(acquisition,st);
oi = piFireFliesRemove(oi);
oiWindow(oi);

%% Convert the oi into an IP

ip = piOI2IP(oi);
ipWindow(ip);
ieNewGraphWin; imagesc(ip.metadata.depthMap); axis image
ieNewGraphWin; imagesc(ip.metadata.meshImage); axis image

%% Save out the corresponding images as PNG files

chdir(fullfile(piRootPath,'local'));
rgb = ipGet(ip,'srgb');
imwrite(rgb,'tmp-radiance.png')
imwrite(ieScale(ip.metadata.depthMap,0,1),'tmp-depth.png')
imwrite(ieScale(ip.metadata.meshImage),'tmp-mesh.png')

depthMap = ip.metadata.depthMap;
meshNumber = ip.metadata.meshImage;
meshLabel = ip.metadata.meshtxt;
save('metadata',depthMap,meshNumber,meshLabel);


%%