function thisR = piGeometryRead(thisR)
% Read a C4d geometry file and extract object information into a recipe
%
% Syntax:
%   renderRecipe = piGeometryRead(renderRecipe)
%
% Input
%   renderRecipe:  an iset3d recipe object describing the rendering
%     parameters.  This object includes the inputFile and the
%     outputFile, which are used to find the  directories containing
%     all of the pbrt scene data.
%
% Return
%    renderRecipe - Updated by the processing in this function
%
% Zhenyi, 2018
% Henryk Blasinski 2020
%
% Description
%   This includes a bunch of sub-functions and a logic that needs further
%   description.
%
% See also
%   piGeometryWrite

%%
p = inputParser;
p.addRequired('thisR',@(x)isequal(class(x),'recipe'));

%% Check version number
if(thisR.version ~= 3)
    error('Only PBRT version 3 Cinema 4D exporter is supported.');
end

%% give a geometry.pbrt

% Best practice is to initalize the ouputFile.  Sometimes people
% don't.  So we do this as the default behavior.
[inFilepath, scene_fname] = fileparts(thisR.inputFile);
inputFile = fullfile(inFilepath,sprintf('%s_geometry.pbrt',scene_fname));

% Save the JSON file at AssetInfo
% outputFile  = renderRecipe.outputFile;
outFilepath = fileparts(thisR.outputFile);
AssetInfo   = fullfile(outFilepath,sprintf('%s.json',scene_fname));

%% Open the geometry file

% Read all the text in the file.  Read this way the text indents are
% ignored.
fileID = fopen(inputFile);
tmp = textscan(fileID,'%s','Delimiter','\n');
txtLines = tmp{1};
fclose(fileID);

%% Check whether the geometry have already been converted from C4D

% If it was converted into ISET3d format, we don't need to do much work.
if piContains(txtLines(1),'# PBRT geometry file converted from C4D exporter output')
    convertedflag = true;
else
    convertedflag = false;
end

if ~convertedflag
    % It was not converted, so we go to work.
    thisR.assets = parseGeometryText(thisR, txtLines,'');

    % jsonwrite(AssetInfo,renderRecipe);
    % fprintf('piGeometryRead done.\nSaving render recipe as a JSON file %s.\n',AssetInfo);
    
else
    % The converted flag is true, so AssetInfo is already stored in a
    % JSON file with the recipe information.  We just copy it isnto the
    % recipe.
    renderRecipe_tmp = jsonread(AssetInfo);
    
    % There may be a utility that accomplishes this.  We should find
    % it and use it here.
    fds = fieldnames(renderRecipe_tmp);
    thisR = recipe;
    
    % Assign the each field in the struct to a recipe class
    for dd = 1:length(fds)
        thisR.(fds{dd})= renderRecipe_tmp.(fds{dd});
    end
    
end


%% Make the node name unique
[thisR.assets, ~] = thisR.assets.uniqueNames;
end

%%
%
function [trees, parsedUntil] = parseGeometryText(thisR, txt, name)
%
% Inputs:
%
%   txt         - remaining text to parse
%   name        - current object name
%
% Outputs:
%   res         - struct of results
%   children    - Attributes under the current object
%   parsedUntil - line number of the parsing end
%
% Description:
%
%   The geometry text comes from C4D export. We parse the lines of text in 
%   'txt' cell array and recrursively create a tree structure of geometric objects.
%   
%   Logic explanation:
%   parseGeometryText will recursively parse the geometry text line by
%   line. If current text is:
%       a) 'AttributeBegin': this is the beginning of a section. We will
%       keep looking for node/object/light information until we reach the 
%       'AttributeEnd'.
%       b) Node/object/light information: this could contain rotation,
%       position, scaling, shape, material properties, light spectrum
%       information. Upon seeing the information, parameters will be
%       created to store the value.
%       c) 'AttributeEnd': this is the end of a section. Depending on
%       parameters in this section, we will create different nodes and make
%       them as trees. Noted the 'branch' node will have children for sure,
%       so we assumed that before reaching the end of 'branch' seciton, we
%       already have some children, so we need to attach them under the
%       'branch'. 'Ojbect' and 'Light', on the other hand will have no child
%       as they will be children leaves. So we simply create leave nodes
%       for them and return.

% res = [];
% groupobjs = [];
% children = [];
subtrees = {};

i = 1;
while i <= length(txt)
    
    currentLine = txt{i};
    
    % Return if we've reached the end of current attribute
    
    if strcmp(currentLine,'AttributeBegin')
        % This is an Attribute inside an Attribute
        [subnodes, retLine] = parseGeometryText(thisR, txt(i+1:end), name);
        subtrees = cat(1, subtrees, subnodes);
        %{
        groupobjs = cat(1, groupobjs, subnodes);
        
        
        % Give an index to the subchildren to make it different from its
        % parents and brothers (we are not sure if it works for more than
        % two levels). We name the subchildren based on the line number and
        % how many subchildren there are already.
        if ~isempty(subchildren)
            subchildren.name = sprintf('%d_%d_%s', i, numel(children)+1, subchildren.name);
        end
        children = cat(1, children, subchildren);
        %}
%         assets = cat(1, assets, subassets);
        i =  i + retLine;
        
    elseif piContains(currentLine,'#ObjectName')
        [name, sz] = piParseObjectName(currentLine);
        
    elseif piContains(currentLine,'ConcatTransform')
        [rot, position] = piParseConcatTransform(currentLine);
        
    elseif piContains(currentLine,'MediumInterface')
        % MediumInterface could be water or other scattering media.
        medium = currentLine;
        
    elseif piContains(currentLine,'NamedMaterial')
        mat = piParseGeometryMaterial(currentLine);
        
    elseif piContains(currentLine,'AreaLightSource')
        areaLight = currentLine;
        
    elseif piContains(currentLine,'LightSource') ||...
            piContains(currentLine, 'Rotate') ||...
            piContains(currentLine, 'Scale')
        % Usually light source contains only one line. Exception is there
        % are rotations or scalings
        if ~exist('lght','var')
            lght{1} = currentLine;
        else
            lght{end+1} = currentLine;
        end
        
    elseif piContains(currentLine,'Shape')
        shape = piParseShape(currentLine);
    elseif strcmp(currentLine,'AttributeEnd')
        
        % Assemble all the read attributes into either a groub object, or a
        % geometry object. Only group objects can have subnodes (not
        % children). This can be confusing but is somewhat similar to
        % previous representation.
        
        % More to explain this long if-elseif-else condition:
        %   First check if this is a light/arealight node. If so, parse the
        %   parameters.
        %   If it is not a light node, then we consider if it is a node
        %   node which records some common translation and rotation.
        %   Else, it must be an object node which contains material info
        %   and other things.
        
        if exist('areaLight','var') || exist('lght','var')
            % This is a 'light' node
            resLight = piAssetCreate('type', 'light');
            if exist('lght','var')
                % Wrap the light text into attribute section
                lghtWrap = [{'AttributeBegin'}, lght(:)', {'AttributeEnd'}];
                resLight.lght = piLightGetFromText(thisR, lghtWrap, 'print', false); 
            end
            if exist('areaLight','var')
                resLight.lght = piLightGetFromText(thisR, {areaLight}, 'print', false); 
                
                if exist('shape', 'var')
                    resLight.lght{1}.shape = shape;
                end
                
                if exist('rot', 'var')
                    resLight.lght{1}.rotate = rot;
                end
                
                if exist('position', 'var')
                    resLight.lght{1}.position = position;
                end
                
            end
            
            if exist('name', 'var'), resLight.name = sprintf('%s', name); end
            
            subtrees = cat(1, subtrees, tree(resLight));
            trees = subtrees;

        elseif exist('rot','var') || exist('position','var')
           % This is a 'branch' node
           
            % resCurrent = createGroupObject();
            resCurrent = piAssetCreate('type', 'branch');
            
            % If present populate fields.
            if exist('name','var'), resCurrent.name = sprintf('%s', name); end
            if exist('sz','var'), resCurrent.size = sz; end
            if exist('rot','var'), resCurrent.rotate = rot; end
            if exist('position','var'), resCurrent.position = position; end
            
            %{
                resCurrent.groupobjs = groupobjs;
                resCurrent.children = children;
                children = [];
                res = cat(1,res,resCurrent);
            %}
            trees = tree(resCurrent);
            for ii = 1:numel(subtrees)
                trees = trees.graft(1, subtrees(ii));
            end
            
        elseif exist('shape','var') || exist('mediumInterface','var') || exist('mat','var')
            % resChildren = createGeometryObject();
            resObject = piAssetCreate('type', 'object');
            if exist('name','var')
                % resObject.name = sprintf('%d_%d_%s',i, numel(subtrees)+1, name); 
                resObject.name = name;
            end

            if exist('shape','var'), resObject.shape = shape; end
            
            if exist('mat','var')
                resObject.material = mat; 
                resObject.name = sprintf('%s_material_%s', resObject.name, mat.namedmaterial);
            end
            if exist('medium','var')
                resObject.medium = medium; 
                resObject.name = sprintf('%s_medium_%s', resObject.name, medium);
            end
            
            subtrees = cat(1, subtrees, tree(resObject));
            trees = subtrees;
           
        elseif exist('name','var')
            % resCurrent = createGroupObject();
            resCurrent = piAssetCreate('type', 'branch');
            if exist('name','var'), resCurrent.name = sprintf('%s', name); end
            
            %{
            resCurrent.groupobjs = groupobjs;
            resCurrent.children = children;
            children = [];
            res = cat(1,res,resCurrent);  
            %}
            trees = tree(resCurrent);
            for ii = 1:numel(subtrees)
                trees = trees.graft(1, subtrees(ii));
            end
        end
        
        parsedUntil = i;
        return;
        
    else
      %  warning('Current line skipped: %s', currentLine);
    end

    i = i+1;
end

%{
res = createGroupObject();
res.name = 'root';
res.groupobjs = groupobjs;
res.children = children;
%}
trees = tree('root');
for ii = 1:numel(subtrees)
    trees = trees.graft(1, subtrees(ii));
end
parsedUntil = i;

end
%}



%%
%%
%{
function [res, children, parsedUntil] = parseGeometryText(txt, name)
%
% Inputs:
%
%   txt         - remaining text to parse
%   name        - current object name
%
% Outputs:
%   res         - struct of results
%   children    - Attributes under the current object
%   parsedUntil - line number of the parsing end
%
% Description:
%
%   The geometry text comes from C4D export. We parse the lines of text in 
%   'txt' cell array and recrursively create a tree structure of geometric objects.

res = [];
groupobjs = [];
children = [];

i = 1;
while i <= length(txt)
    
    currentLine = txt{i};
    
    % Return if we've reached the end of current attribute
    if strcmp(currentLine,'AttributeEnd')
        
        % Assemble all the read attributes into either a groub object, or a
        % geometry object. Only group objects can have subnodes (not
        % children). This can be confusing but is somewhat similar to
        % previous representation.
        
        if exist('rot','var') || exist('position','var')
            resCurrent = createGroupObject();
            
            % If present populate fields.
            if exist('name','var'), resCurrent.name = name; end
            if exist('sz','var'), resCurrent.size = sz; end
            if exist('rot','var'), resCurrent.rotate = rot; end
            if exist('position','var'), resCurrent.position = position; end
            
            resCurrent.groupobjs = groupobjs;
            resCurrent.children = children;
            children = [];
            res = cat(1,res,resCurrent);
            
        elseif exist('shape','var') || exist('mediumInterface','var') || exist('mat','var') || exist('areaLight','var') || exist('lght','var')
            resChildren = createGeometryObject();
            
            if exist('shape','var'), resChildren.shape = shape; end
            if exist('medium','var'), resChildren.medium = medium; end
            if exist('mat','var'), resChildren.material = mat; end
            if exist('lght','var'), resChildren.light = lght; end
            if exist('areaLight','var'), resChildren.areaLight = areaLight; end
            if exist('name','var'), resChildren.name = name; end
            
            children = cat(1,children, resChildren);
        
        elseif exist('name','var')
            resCurrent = createGroupObject();
            if exist('name','var'), resCurrent.name = name; end
           
            resCurrent.groupobjs = groupobjs;
            resCurrent.children = children;
            children = [];
            res = cat(1,res,resCurrent);  
        end
           
        parsedUntil = i;
        return;
        
    elseif strcmp(currentLine,'AttributeBegin')
        % This is an Attribute inside an Attribute
        [subnodes, subchildren, retLine] = parseGeometryText(txt(i+1:end), name);
        groupobjs = cat(1, groupobjs, subnodes);
        
        % Give an index to the subchildren to make it different from its
        % parents and brothers (we are not sure if it works for more than
        % two levels). We name the subchildren based on the line number and
        % how many subchildren there are already.
        if ~isempty(subchildren)
            subchildren.name = sprintf('%d_%d_%s', i, numel(children)+1, subchildren.name);
        end
        children = cat(1, children, subchildren);
        i =  i + retLine;
        
    elseif piContains(currentLine,'#ObjectName')
        [name, sz] = parseObjectName(currentLine);
        
    elseif piContains(currentLine,'ConcatTransform')
        [rot, position] = parseConcatTransform(currentLine);
        
    elseif piContains(currentLine,'MediumInterface')
        % MediumInterface could be water or other scattering media.
        medium = currentLine;
        
    elseif piContains(currentLine,'NamedMaterial')
        mat = currentLine;
        
    elseif piContains(currentLine,'AreaLightSource')
        areaLight = currentLine;
        
    elseif piContains(currentLine,'LightSource') ||...
            piContains(currentLine, 'Rotate') ||...
            piContains(currentLine, 'Scale')
        if ~exist('lght','var')
            lght{1} = currentLine;
        else
            lght{end+1} = currentLine;
        end
        
    elseif piContains(currentLine,'Shape')
        shape = currentLine;
    else
      %  warning('Current line skipped: %s', currentLine);
    end

    i = i+1;
end

res = createGroupObject();
res.name = 'root';
res.groupobjs = groupobjs;
res.children = children;

parsedUntil = i;

end


%%
function obj = createGroupObject()
% Initialize a structure representing a group object.
%
% What makes something a group object rather than a child?
% What if we want to read the nodes and edges of an object, can we do it?

obj.name = [];      % String
obj.size.l = 0;     % Length
obj.size.w = 0;     % Width
obj.size.h = 0;     % Height
obj.size.pmin = [0 0];    % No idea
obj.size.pmax = [0 0];    % No idea

obj.scale = [1 1 1];
obj.position = [0 0 0];   % Maybe the middle of the object?

obj.rotate = [0 0 0;
              0 0 1;
              0 1 0;
              1 0 0];

obj.children = [];
obj.groupobjs = [];
          

end

%%
function obj = createGeometryObject()

% This function creates a geometry object and initializes all fields to
% empty values.

obj.name = [];
obj.index = [];
obj.mediumInterface = [];
obj.material = [];
obj.light = [];
obj.areaLight = [];
obj.shape = [];
obj.output = [];

end
%}
