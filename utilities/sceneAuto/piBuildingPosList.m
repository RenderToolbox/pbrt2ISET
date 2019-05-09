function [buildingPosList] = piBuildingPosList(buildingList, objects)
% Random put buildings in one given region.
%
% Syntax:
%   buildingPosList = piBuildingPosList(buildingList, objects)
%
% Description:
%    Given the info of spare region(length in x axis, length in y axis and
%    coordinate origin) and a building list including the building name and
%    size. Return a settle list, record the settle positions and building
%    name.
%
%    input of subfunction:(generated according to Input)
%       lenx_tmp: lenth of spare region in x axis
%       leny_tmp: lenth of spare region in y axis
%       coordinate: origin coordinate(lower left point of building, when
%       face to the building).
%       type: define what kind of batch the region is.
%               including:'front', 'left', 'right', 'back', means the
%               building area in front/left/right/back of the road.
%
% Inputs:
%    buildingList    - including the building size and name
%    objects         - recipe of assets. e.g. thisR
%
% Output:
%    buildingPosList - record how to settle buildings on the given region,
%                      including building position and building
%                      name(position refer to the lower left point.
%
% Optional key/value pairs:
%    offset          - Numeric. A numeric value used to adjust the interval
%                      between the buildings. Default is 2.
%
% See Also:
%   piBuildingPlace
%

% History:
%    09/21/18  JZ   Jiaqi Zhang 09.21.2018
%    04/09/19  JNM  Documentation pass
%    04/18/19  JNM  Merge Master in (resolve conflicts)
%    05/09/19  JNM  Merge Master in again

%%
buildingPosList = struct;
for ii = 1:length(buildingList)
    building_list.size(ii, 1) = buildingList(ii).geometry.size.l;
    building_list.size(ii, 2) = buildingList(ii).geometry.size.w;
    building_list.name{ii} = buildingList(ii).geometry.name;
end

% tmp = 0;
count = 1;  % initial parameters
buildingPosList_tmp = struct;
sum = 0;
for mm = 1:length(buildingList)
    sum = buildingList(mm).geometry.size.w + sum;
end
% calculate the average width of all the buildings. Variable aveW can be
% used to delete unnecessary buildings in the scene
aveW = sum / length(buildingList) + 10;
for kk = 1:length(objects.assets)
    name = strsplit(objects.assets(kk).name, '_');
    if strcmp(name{1}, 'Plane') % if the object is a building region.
        count_before = count;
        type = name{2};  % extract region information
        lenx_tmp = objects.assets(kk).size.l;
        leny_tmp = objects.assets(kk).size.w;
        coordination = objects.assets(kk).position;
        y_up = coordination(2);
        coordination = [coordination(1), coordination(3)];
        switch type
            case 'front'
                if coordination(1) < 0
                    ankor = coordination + [lenx_tmp, 1];
                else
                    ankor = coordination;
                end
            case 'back'
                if coordination(1) > 0
                    ankor = coordination - [lenx_tmp, 1];
                else
                    ankor = coordination;
                end
            otherwise
                ankor = coordination;
        end
        [buildingPosList_tmp, count] = buildingPlan(building_list, ...
            lenx_tmp, leny_tmp, coordination, buildingPosList_tmp, ...
            count, type, ankor, aveW);

        % %% Delete unnecessary buildings from building list
        % if initialStruct == 1   % for struct's first use, initialize it
        %     FieldName = fieldnames(buildingPosList_tmp)';
        %     FieldName{2, 1} = {};
        %     buildingPosListDeleted = struct(FieldName{:});
        %     initialStruct = 0;
        % end
        %     finalCount = count_before;
        %     margin = 10;
        %     for ll = count_before:count
        %         if (abs(coordination(1) - ...
        %                 buildingPosList_tmp(ll).position(1)) < ...
        %                 (lenx_tmp / margin)) || ...
        %                 (abs(coordination(2) - ...
        %                 buildingPosList_tmp(ll).position(2)) < ...
        %                 (leny_tmp / margin))
        %             buildingPosListDeleted(finalCount) = ...
        %                 buildingPosList_tmp(ll);
        %             finalCount = finalCount + 1;
        %         end
        %     end

        %% change the structure of the output data
        for jj = count_before:length(buildingPosList_tmp)
            buildingPosList(jj).name = buildingPosList_tmp(jj).name;
            buildingPosList(jj).position = [...
                buildingPosList_tmp(jj).position(1), y_up, ...
                buildingPosList_tmp(jj).position(2)];
            buildingPosList(jj).rotate = buildingPosList_tmp(jj).rotate;
        end

        %% test algotithm. Comment this part when using.
        figure(1);
        hold on;
        xlim([-130, 130]);
        ylim([-30, 280]);
        hold on;
        switch type
            case 'front'
                % test algorithm for 'front' situation
                for jj = count_before:length(buildingPosList)
                    for ii = 1:size(building_list.name, 2)
                        if strcmpi(building_list.name(ii), ...
                                buildingPosList(jj).name)
                            xx = building_list.size(ii, 1);
                            yy = building_list.size(ii, 2);
                        end
                    end
                    rectangle('Position', ...
                        [buildingPosList(jj).position(1), ...
                        buildingPosList(jj).position(3), xx, yy]);
                    title('front');
                end
            case 'right'
                % test algorithm for 'right' situation
                for jj = count_before:length(buildingPosList)
                    for ii = 1:size(building_list.name, 2)
                        if strcmpi(building_list.name(ii), ...
                                buildingPosList(jj).name)
                            xx = building_list.size(ii, 1);
                            yy = building_list.size(ii, 2);
                        end
                    end
                    rectangle('Position', [...
                        buildingPosList(jj).position(1), ...
                        buildingPosList(jj).position(3) - xx, yy, xx]);
                    title('right');
                end
            case 'left'
                % test algorithm for 'left' situation
                for jj = count_before:length(buildingPosList)
                    for ii = 1:size(building_list.name, 2)
                        if strcmpi(building_list.name(ii), ...
                                buildingPosList(jj).name)
                            xx = building_list.size(ii, 1);
                            yy = building_list.size(ii, 2);
                        end
                    end
                    rectangle('Position', [...
                        buildingPosList(jj).position(1) - yy, ...
                        buildingPosList(jj).position(3), yy, xx]);
                    title('left');
                end
            case 'back'
                % test algorithm for 'back' situation
                for jj = count_before:length(buildingPosList)
                    for ii = 1:size(building_list.name, 2)
                        if strcmpi(building_list.name(ii), ...
                                buildingPosList(jj).name)
                            xx = building_list.size(ii, 1);
                            yy = building_list.size(ii, 2);
                        end
                    end
                    rectangle('Position', [...
                        buildingPosList(jj).position(1) - xx, ...
                        buildingPosList(jj).position(3) - yy, xx, yy]);
                    title('back');
                end
        end

        % tmp = tmp + 1; 
        % disp(tmp);
    end
end

end

function [settle_list, count] = buildingPlan(building_list, lenx_tmp, ...
    leny_tmp, coordination, settle_list, count, type, ankor, aveW)
% Adjust the spacing interval between buildings.
%
% Syntax:
%   [settle_list, count] = buildingPlan(building_list, lenx_tmp, ...
%       leny_tmp, coordination, settle_list, count, type, ankor, aveW)
%
% Description:
%    Adjust the interval between the buildings. If this is set too large it
%    will cause problems.
%
% Inputs:
%    building_list - Struct. A structure containing all of the information
%                    about the buildings in the scene.
%    lenx_tmp      - Numeric. The length of spare region in x direction.
%    leny_tmp      - Numeric. The length of spare region in y direction.
%    coordination  - Matrix. A 1x2 matrix of area coordinates.
%    settle_list   - Struct. An array of structures containing position
%                    information for the buildings, of length count.
%    count         - Numeric. The number of buildings in the scene.
%    type          - String. The direction of the region. Options are
%                    'front', 'right', 'left', and 'back'.
%    ankor         - Matrix. A 1x2 matrix of anchor coordinates.
%    aveW          - Numeric. The average width for margins along x.
%
% Outputs:
%    settle_list   - Struct. The modified structure array, of length count.
%    count         - Numeric. The number of buildings in the scene.
%
% Optional key/value pairs:
%    None.
%

offset = 0.2;

%% calculate the parameter in spare region.
switch type
    case 'front'
        % ABCD are 4 vertices of spare region
        A = [coordination(1), coordination(2) + leny_tmp];
        B = coordination;
        C = [coordination(1) + lenx_tmp, coordination(2)];
        D = [coordination(1) + lenx_tmp, coordination(2) + leny_tmp];
        lenx = lenx_tmp;  % lenx - lenth of spare region in x direction
        leny = leny_tmp;  % leny - lenth of spare region in y direction
    case 'right'
        % ABCD are 4 vertices of spare region
        A = [coordination(1), coordination(2) - leny_tmp];
        B = coordination;
        C = [coordination(1) + lenx_tmp, coordination(2)];
        D = [coordination(1) + lenx_tmp, coordination(2) - leny_tmp];
        leny = lenx_tmp;  % lenx - lenth of spare region in x direction
        lenx = leny_tmp;  % leny - lenth of spare region in y direction
    case 'left'
        % ABCD are 4 vertices of spare region
        A = [coordination(1) - lenx_tmp, coordination(2)];
        B = coordination;
        C = [coordination(1), coordination(2) + leny_tmp];
        D = [coordination(1) - lenx_tmp, coordination(2) + leny_tmp];
        leny = lenx_tmp;  % lenx - lenth of spare region in x direction
        lenx = leny_tmp;  % leny - lenth of spare region in y direction
    case 'back'
        % ABCD are 4 vertices of spare region
        A = [coordination(1), coordination(2) - leny_tmp];
        B = coordination;
        C = [coordination(1) - lenx_tmp, coordination(2)];
        D = [coordination(1) - lenx_tmp, coordination(2) - leny_tmp];
        lenx = lenx_tmp;  % lenx - lenth of spare region in x direction
        leny = leny_tmp;  % leny - lenth of spare region in y direction
end

% selectx is a list of the index of buildings that can be put in spare
% region in x direction.
selectx = find(building_list.size(:, 1) <= lenx);
selecty = find(building_list.size(:, 2) <= leny);
% sel record the index of buildings that can be put in spare region
sel = intersect(selectx, selecty);
% disp(sel)

%% Decide if there is any building which can be put in the spare region
% If possiple, add it to the spare region, record the position and id of
% the building in the spare region. Then update the new spare region,
% followed by recursion.
if ~isempty(sel)    % it is possible to put a new building on spare region
    % randomly get index of proper building
    building_idx = sel(randi([1, length(sel)], 1, 1));
    % Retrieve the name & size of the proper building
    id = building_list.name{building_idx};
    build_x = building_list.size(building_idx, 1) + offset;
    build_y = building_list.size(building_idx, 2) + offset;
    switch type
        case 'front'
            % calculate info of spare region 1
            A1 = A;
            B1 = B + [0, build_y];
            C1 = B + [build_x, build_y];
            D1 = [B(1) + build_x, A(2)];
            next_x1 = build_x;
            next_y1 = A1(2) - B1(2);

            % calculate info of spare region 2
            A2 = D1;
            B2 = B + [build_x, 0];
            C2 = C;
            D2 = D;
            next_x2 = C2(1) - B2(1);
            next_y2 = D2(2) - C2(2);

            % record the info of the new biulding, including id, x and y
            % coordinates. Only record the building's information that
            % confirms our requirments.
            if B(1) < 0   % delete unnecessary buildings
                marginX = aveW;
                marginY = 2;
            else
                marginX = 2;
                marginY = 2;
            end

            if (abs(ankor(1) - B(1)) < marginX) || ...
                    (abs(ankor(2) - B(2)) < marginY)
                settle_list(count).name = id;
                settle_list(count).position(1, 1) = B(1);
                settle_list(count).position(1, 2) = B(2);
                settle_list(count).rotate = 0;
                count = count + 1;  % count the buildings amount
            end

            % recursion, spare region 1 is priority
            [settle_list, count] = buildingPlan(building_list, next_x1, ...
                next_y1, B1, settle_list, count, type, ankor, aveW);
            [settle_list, count] = buildingPlan(building_list, next_x2, ...
                next_y2, B2, settle_list, count, type, ankor, aveW);

        case 'right'
            A1 = A;
            B1 = B + [0, -build_x];
            C1 = B + [build_y, -build_x];
            D1 = [B(1) + build_y, A(2)];
            next_x1 = build_y;
            next_y1 = B1(2) - A1(2);

            A2 = D1;
            B2 = B + [build_y, 0];
            C2 = C;
            D2 = D;
            next_x2 = C2(1) - B2(1);
            next_y2 = C2(2) - D2(2);

            if abs(ankor(1)-B(1))<1  % ||(abs(ankor(2)-B(2))<11)
                settle_list(count).name = id;
                settle_list(count).position(1, 1) = B(1);
                settle_list(count).position(1, 2) = B(2);
                settle_list(count).rotate = 90;
                count = count + 1;  % count the buildings amount
            end
            % recursion, spare region 1 is priority
            [settle_list, count] = buildingPlan(building_list, next_x1, ...
                next_y1, B1, settle_list, count, type, ankor, aveW);
            [settle_list, count] = buildingPlan(building_list, next_x2, ...
                next_y2, B2, settle_list, count, type, ankor, aveW);

        case 'left'
            % calculate info of spare region 1
            A1 = A;
            B1 = B + [-build_y, 0];
            C1 = B + [-build_y, build_x];
            D1 = A + [0, build_x];
            next_x1 = B1(1) - A1(1);
            next_y1 = build_x;

            % calculate info of spare region 2
            A2 = D1;
            B2 = B + [0, build_x];
            C2 = C;
            D2 = D;
            next_x2 = C2(1) - D2(1);
            next_y2 = C2(2) - B2(2);

            if abs(ankor(1)-B(1))<1%||(abs(ankor(2)-B(2))<11)
                % record the following info for the new building:
                % id, x and y coordinates
                settle_list(count).name = id;
                settle_list(count).position(1, 1) = B(1);
                settle_list(count).position(1, 2) = B(2);
                settle_list(count).rotate = 270;
                count = count + 1;  % count the buildings amount
            end

            % recursion, spare region 1 is priority
            [settle_list, count] = buildingPlan(building_list, next_x1, ...
                next_y1, B1, settle_list, count, type, ankor, aveW);
            [settle_list, count] = buildingPlan(building_list, next_x2, ...
                next_y2, B2, settle_list, count, type, ankor, aveW);

        case 'back'
            % calculate info of spare region 1
            A1 = A;
            B1 = B + [0, -build_y];
            C1 = B + [-build_x, -build_y];
            D1 = [B(1)-build_x, A(2)];
            next_x1 = build_x;
            next_y1 = B1(2) - A1(2);

            % calculate info of spare region 2
            A2 = D1;
            B2 = B + [-build_x, 0];
            C2 = C;
            D2 = D;
            next_x2 = B2(1) - C2(1);
            next_y2 = C2(2) - D2(2);

            if B(1) > 0  % delete unnecessary buildings
                marginX = aveW;
                marginY = 2;
            else
                marginX = 2;
                marginY = 2;
            end

            if (abs(ankor(1) - B(1)) < marginX) || ...
                    (abs(ankor(2) - B(2)) < marginY)
                % record the info of new building: id, x and y coordinates
                settle_list(count).name = id;
                settle_list(count).position(1, 1) = B(1);
                settle_list(count).position(1, 2) = B(2);
                settle_list(count).rotate = 180;
                count = count + 1;  % count the buildings amount
            end

            % recursion, spare region 1 is priority
            [settle_list, count] = buildingPlan(building_list, next_x1, ...
                next_y1, B1, settle_list, count, type, ankor, aveW);
            [settle_list, count] = buildingPlan(building_list, next_x2, ...
                next_y2, B2, settle_list, count, type, ankor, aveW);
    end
else
    % Not possible to add a building to the spare region, exit recursion.
end

end
