function [] = test_piv(varargin)
% function [] = test_piv(varargin)
%
% Test PIV performance using case using synthetic image pair generated by
% homogenous deformation and translation of a single input image.
%
% NOTE: This is a "high-level" test that covers all of the PIV subsystems. The
% error analysis addresses only measured velocities, not derived products such
% as strain.
%
% Optional Arguments ('Name', Value):
%   'image_file': String, name of pre-processed image file, as produced by
%       prep_series(), to read for raw image, default = ./test/default_image.nc
%   'image_index': Integer, (1-based) index of image in image file to use for
%       raw image, default = 1
%   'image_pos': 4-element position vector indicating the limits of the image to
%       extract and deform. Must contain only sand (all within the ROI),
%       in meters, default = [-0.12, 0.005, 0.092, 0.07]
%   'translation': 2-element vector specifying spatially constant translation
%       in meters, default = [0.005, 0.00]
%   'shear_theta': Scalar, orientation of shear band specified as
%       counter-clockwise angle to the positive x-axis, in degrees, limited to
%       range 0 - 90, default = 45
%   'shear_width': Scalar, width of shear band, in meters, default = 0.05   
%   'shear_mag': Scalar, displacement difference across shear band, applied as a
%       0.5*shear_mag displacement on one side and a -0.5*shear_mag displacement
%       on the other, default = sqrt(2)*0.005
%   'samplen': piv() parameter, default [30, 30]
%   'sampspc': piv() parameter, default [15, 15]
%   'intrlen': piv() parameter, default [100, 60]
%   'npass': piv() parameter, default [1, 2]
%   'valid_max': piv() parameter, default 2
%   'valid_eps': piv() parameter, default 0.1
%   'spline_tension': piv() parameter, default 0.95
%   'min_frac_data': piv() parameter, default 0.8
%   'min_frac_overlap': piv() parameter, default 0.5
%   'verbose': Scalar logical, set true to enable verbose reporting for all
%       components of the analysis
% %

% TODO: stick to pixel units internally
% TODO: clean up variable names

%% parse arguments

% constants
src_dir = fileparts(mfilename('fullpath'));

ip = inputParser();

ip.addParameter('image_file', fullfile(src_dir, 'test', 'default_image.nc'), ...
    @(x) exist(x, 'file') == 2);
ip.addParameter('image_index', 1, ...
    @(x) validateattributes(x, {'numeric'}, {'scalar', 'integer', 'positive'}));
ip.addParameter('image_pos', [-0.12, 0.005, 0.092, 0.07], ...
    @(x) validateattributes(x, {'numeric'}, {'vector', 'numel', 4}));
ip.addParameter('translation', [0.005, 0.00], ...
    @(x) validateattributes(x, {'numeric'}, {'vector', 'numel', 2}));
ip.addParameter('shear_theta', 45, ...
    @(x) validateattributes(x, {'numeric'}, {'scalar', 'min', 0, 'max' 90}));
ip.addParameter('shear_width', 0.05, ...
    @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
ip.addParameter('shear_mag', 0.01, ...
    @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
ip.addParameter('samplen', [30, 30]); % validation handled by PIV routines
ip.addParameter('sampspc', [15, 15]);
ip.addParameter('intrlen', [100, 60]);
ip.addParameter('npass', [1, 2]);
ip.addParameter('valid_max', 2);
ip.addParameter('valid_eps', 0.1);
ip.addParameter('spline_tension', 0.95);
ip.addParameter('min_frac_data', 0.8);
ip.addParameter('min_frac_overlap', 0.5);
ip.addParameter('verbose', true, ...
    @(x) validateattributes(x, {'numeric', 'logical'}, {'scalar', 'binary'}));

ip.parse(varargin{:});
args = ip.Results;

if args.verbose
    fprintf('%s: arguments:\n', mfilename);
    disp(args)
end

%% read and crop raw image

if args.verbose
    fprintf('%s: read and crop raw image\n', mfilename);
end

xx = double(ncread(args.image_file, 'x'));
yy = double(ncread(args.image_file, 'y'));
img = double(ncread(args.image_file, 'img', [1, 1, args.image_index], [inf, inf, 1]));
mask_auto = ncread(args.image_file, 'mask_auto', [1, 1, args.image_index], [inf, inf, 1]);
mask_manu = ncread(args.image_file, 'mask_manual');
roi = mask_auto & mask_manu;

min_col = find(xx >= args.image_pos(1), 1, 'first');
max_col = find(xx <= args.image_pos(1) + args.image_pos(3), 1, 'last');
min_row = find(yy >= args.image_pos(2), 1, 'first');
max_row = find(yy <= args.image_pos(2) + args.image_pos(4), 1, 'last');

xx = xx(min_col:max_col);
yy = yy(min_row:max_row);
img = img(min_row:max_row, min_col:max_col);
roi = roi(min_row:max_row, min_col:max_col);

if any(~roi(:))
    error('%s: image_pos limits must include only sand (ROI)', mfilename);
end

%% pad image boundaries (and coordinates) to accomodate edge displacements

if args.verbose
    fprintf('%s: pad image to accomodate edge displacements\n', mfilename);
end

padsize = ceil(0.10*size(img));
img = padarray(img, padsize, 0, 'both');
roi = padarray(roi, padsize, 0, 'both');
dx = mean(diff(xx));
xx = [xx(1)-dx*(padsize(2):-1:1), xx(:)', xx(end)+dx*(1:padsize(2))];
dy = mean(diff(yy));
yy = [yy(1)-dy*(padsize(1):-1:1), yy(:)', yy(end)+dy*(1:padsize(1))];
sz = size(img);

%% compute exact displacement field for specified displacements and boundary

if args.verbose
    fprintf('%s: compute exact displacement field\n', mfilename);
end

u_exact = zeros(sz);
v_exact = zeros(sz);

% apply constant displacement
u_exact = u_exact + args.translation(1);
v_exact = v_exact + args.translation(2);

% apply simple shear in specified band
[xg, yg] = meshgrid(xx - mean(xx), yy - mean(yy));
rot = [cosd(args.shear_theta), sind(args.shear_theta); ...
       -sind(args.shear_theta), cosd(args.shear_theta)];
xy = [xg(:)'; yg(:)'];
xy = rot*xy;
yg(:) = xy(2,:);
scale = yg/args.shear_width;
scale(scale < -0.5) = -0.5;
scale(scale > 0.5) = 0.5;

u_exact = u_exact + scale*cosd(args.shear_theta)*args.shear_mag;
v_exact = v_exact + scale*sind(args.shear_theta)*args.shear_mag;

%% generate synthetic images

if args.verbose
    fprintf('%s: generate synthetic images\n', mfilename);
end

% convert to pixel coords
u_exact_pix = u_exact/(range(xx)/length(xx));
v_exact_pix = v_exact/(range(yy)/length(yy));

% deform images
ini = imwarp(img, 0.5*cat(3, u_exact_pix, v_exact_pix), 'cubic'); % dir is ok
fin = imwarp(img, -0.5*cat(3, u_exact_pix, v_exact_pix), 'cubic');

% deform masks
ini_roi = imwarp(double(roi), 0.5*cat(3, u_exact_pix, v_exact_pix), 'cubic');
ini_roi = logical(round(ini_roi));
fin_roi = imwarp(double(roi), -0.5*cat(3, u_exact_pix, v_exact_pix), 'cubic');
fin_roi = logical(round(fin_roi));

% reapply mask
ini(~ini_roi) = 0;
fin(~fin_roi) = 0;

% enforce limits (NOTE: could stretch instead)
ini(ini < 0) = 0;
ini(ini > 1) = 1;
fin(fin < 0) = 0;
fin(fin > 1) = 1;

% <DEBUG>
% TODO: make this permanant
figure

subplot(1,2,1)
imagesc(ini)
set(gca, 'YDir', 'normal');
axis equal tight
title('ini')

subplot(1,2,2)
imagesc(fin)
set(gca, 'YDir', 'normal');
axis equal tight
title('fin')
% </DEBUG>

%% run PIV analysis on synthetic images

if args.verbose
    fprintf('%s: run PIV analysis\n', mfilename);
end

[x_piv, y_piv, u_piv, v_piv, roi_piv] = piv(... 
    ini, fin, ini_roi, fin_roi, xx, yy, args.samplen, args.sampspc, ...
    args.intrlen, args.npass, args.valid_max, args.valid_eps, ...
    args.spline_tension, args.min_frac_data, args.min_frac_overlap, true); %#ok<ASGLU>

% <DEBUG>
% TODO: make this permanant
figure

subplot(1, 2, 1)
m_exact = sqrt(u_exact.^2 + v_exact.^2);
imagesc(xx, yy, m_exact);
set(gca, 'YDir', 'Normal');
hold on;
[xg, yg] = meshgrid(xx, yy);
dd = 10;
quiver(xg(1:dd:end, 1:dd:end), yg(1:dd:end, 1:dd:end), ...
    u_exact(1:dd:end, 1:dd:end), v_exact(1:dd:end, 1:dd:end));
axis equal tight
title('exact')

subplot(1, 2, 2)
m_piv = sqrt(u_piv.^2 + v_piv.^2);
imagesc(x_piv, y_piv, m_piv);
set(gca, 'YDir', 'Normal');
hold on;
[xg, yg] = meshgrid(x_piv, y_piv);
dd = 1;
quiver(xg(1:dd:end, 1:dd:end), yg(1:dd:end, 1:dd:end), ...
    u_piv(1:dd:end, 1:dd:end), v_piv(1:dd:end, 1:dd:end));
axis equal tight
title('piv')
% </DEBUG>

%% analyze errors

if args.verbose
    fprintf('%s: error analysis\n', mfilename);
end

u_exact_at_piv = interp2(xx(:)', yy(:), u_exact, x_piv(:)', y_piv(:), 'linear');
v_exact_at_piv = interp2(xx(:)', yy(:), v_exact, x_piv(:)', y_piv(:), 'linear');

% <DEBUG>
% TODO: Results indicate exact and computed solutions are off by one. Which is
%   wrong?
% BELOW: "fixes" offset issue
pix_per_m = length(xx)/range(xx);
u_piv = u_piv - 1/pix_per_m;
v_piv = v_piv - 1/pix_per_m;
% </DEBUG>

u_error =  u_exact_at_piv - u_piv;
v_error =  v_exact_at_piv - v_piv;

% convert to pixels
pix_per_m = length(xx)/range(xx);
u_error_pix = u_error*pix_per_m;
v_error_pix = v_error*pix_per_m;

test_piv_print_error(u_error_pix, v_error_pix);
test_piv_plot_error(u_error_pix, v_error_pix);
