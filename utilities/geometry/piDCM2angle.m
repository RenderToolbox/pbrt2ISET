function [r1, r2, r3] = piDCM2angle(dcm)
% Simplified version of the Aerospace toolbox angle conversion utility
%
% Syntax:
%   [r1, r2, r3] = piDCM2angle(dcm)
%
% Description:
%    The case that we compute is this one. There are many others and
%    various options in the Mathworks dcm2angle.m code.
%
%       [          cy*cz,          cy*sz,   -sy]
%       [ sy*sx*cz-sz*cx, sy*sx*sz+cz*cx, cy*sx]
%       [ sy*cx*cz+sz*sx, sy*cx*sz-cz*sx, cy*cx]
%
% Inputs:
%    dcm - Matrix. A 3D array of matrices.
%
% Outputs:
%    r1  - Vector. The zAngle rotation angle for the matrix.
%    r2  - Vector. The yAngle rotation angle for the matrix.
%    r3  - Vector. The xAngle rotation angle for the matrix.
%
% Optional key/value pairs
%    None.
%
% Notes:
%    * TODO: Zhenyi to make sure that this function returns the same as
%      dcm2angle in the Aerospace toolbox for this case.
%
% See Also:
%   piRotationDefault, piGeometryRead
%

% History:
%    XX/XX/XX  XXX  Created
%    04/02/19  JNM  Documentation pass
%    04/18/19  JNM  Merge Master in (resolve conflicts)

% Examples:
%{
    dcm(:, :, 1) = eye(3);
    dcm(:, :, 2) = eye(3);
    [z, y, x] = piDCM2angle(dcm)
%}

%% Should validate here

% [Note: TL - Validate seems to fail for certain scenes. Commenting out for
% now until we figure out what's going on.]
% validatedcm(dcm);

% This is the transform
% [r1, r2, r3] = threeaxisrot(dcm(1, 2, :), ...
%     dcm(1, 1, :), -dcm(1, 3, :), dcm(2, 3, :), ...
%     dcm(3, 3, :), -dcm(2, 1, :), dcm(2, 2, :));
[r1, r2, r3] = threeaxisrot(dcm(1, 2, :), dcm(1, 1, :), -dcm(1, 3, :), ...
    dcm(2, 3, :), dcm(3, 3, :));

r1 = r1(:);
r2 = r2(:);
r3 = r3(:);

end

function [r1, r2, r3] = threeaxisrot(r11, r12, r21, r31, r32)
% find angles for rotations about X, Y, and Z axes
%
% Syntax:
%   [r1, r2, r3] = threeaxisrot(r11, r12, r21, r31, r32)
%
% Description:
%    Find the angles for rotations about the X, Y, and Z axes.
%
% Inputs:
%    r11 - Matrix. A rotation matrix.
%    r12 - Matrix. A rotation matrix.
%    r21 - Matrix. A rotation matrix.
%    r31 - Matrix. A rotation matrix.
%    r32 - Matrix. A rotation matrix.
%
% Outputs:
%    r1  - Matrix. The Z axis rotation angle.
%    r2  - Matrix. The Y axis rotation angle.
%    r3  - Matrix. The X axis rotation angle.
%
% Optional key/value pairs:
%    None.
%
r1 = atan2(r11, r12);
r2 = asin(r21);
r3 = atan2(r31, r32);

%{
% The original implements this special case of zero rotation on the
% 3rd dimension. Does not seem relevant to us
if strcmpi(lim, 'zeror3')
    for i = find(abs(r21) >= 1.0)
        r1(i) = atan2(r11a(i), r12a(i));
        r2(i) = asin(r21(i));
        r3(i) = 0;
    end
end
%}

end

function validatedcm(dcm)
% An internal function to check that the input dcm is orthogonal & proper.
%
% Syntax:
%   validatedcm(dcm)
%
% Description:
%    An internal function to check that the input dcm is both orthogonal
%    and proper.
%
%    The criteria for this check are:
%        - The transpose of the matrix multiplied by the matrix equals
%          1 +/- tolerance
%        - Determinant of matrix == +1
%
% Inputs:
%    dcm - Matrix. The input matrix to validate.
%
% Outputs:
%    None.
%
% Optional key/value pairs:
%    None.
%

tolerance = 1e-6;
for ii = 1:size(dcm, 3)
    x = dcm(:, :, ii) * dcm(:, :, ii)';
    d = (x - eye(3));
    assert(max(d(:)) < tolerance);
    assert(det(x) - 1 < tolerance);
end

end
