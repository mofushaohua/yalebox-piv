function [] = test_piv_run_image(force)
%
% Run a hard-coded test case using a synthetic image pair as generated by
% test_piv_create_image.
%
% Arguments:
%
% force = Scalar, binary, flag indicating whether to force recomputing input
%   variables (1) or not (0). This is useful if the downstream code has changed,
%   but input parameters have not.
%
% %

%% parameters

% image parameters
tform = [1, 0.05, 0;  
         0,    1, 0];
bnd_mean = 0.7;
bnd_ampl = 0.1;
bnd_freq = 1;

% piv parameters
samplen = [30, 30];
sampspc = [15, 15];
intrlen = [100, 40];
npass = [1, 10];
valid_max = 2;
valid_eps = 0.01;
lowess_span_pts = 16;
spline_tension = 0.95;
min_frac_data = 0.8;
min_frac_overlap = min_frac_data/2;
low_res_spc = 10;

% local parameters
data_file = 'test/image.mat';
func_name = 'test_piv_run_image';

%% parse arguments and set defaults

narginchk(0,1);
if nargin == 0 || isempty(force) 
    force = 0;
end

validateattributes(force, {'numeric'}, {'scalar', 'binary'});

%% generate (or load) test images

% check if defined parameters match saved parameters
try
    F = load(data_file, 'tform', 'bnd_mean', 'bnd_ampl', 'bnd_freq');
    same = all(F.tform(:) == tform(:)) && ...
        F.bnd_mean == bnd_mean && ...
        F.bnd_ampl == bnd_ampl && ...
        F.bnd_freq == bnd_freq;
catch
    same = 0;
end

% report status
if same 
    fprintf('%s: Parameters are not modified\n', func_name); 
else
    fprintf('%s: Parameters are modified\n', func_name); 
end
if force
    fprintf('%s: Force recompute enabled\n', func_name);
else
    fprintf('%s: Force recompute disabled\n', func_name);
end

% load PIV input data
if same && ~force
    fprintf('%s: Loading input variables from file\n', func_name);
    F = load(data_file, 'ini', 'ini_roi', 'fin', 'fin_roi', 'xx', 'yy');
    ini = F.ini;
    ini_roi = F.ini_roi;
    fin = F.fin;
    fin_roi = F.fin_roi;
    xx = F.xx;
    yy = F.yy;
    
else
    fprintf('%s: Generating new input variables\n', func_name);
    [ini, fin, ini_roi, fin_roi, xx, yy] = ...
        test_piv_create_image(tform, bnd_mean, bnd_ampl, bnd_freq);
    save(data_file, 'tform', 'bnd_mean', 'bnd_ampl', 'bnd_freq', 'ini', ...
            'ini_roi', 'fin', 'fin_roi', 'xx', 'yy');
end

clear F

%% run PIV and analyze results

% run piv
[xx, yy, uu, vv] = piv(ini, fin, ini_roi, fin_roi, xx, yy, samplen, ...
    sampspc, intrlen, npass, valid_max, valid_eps, lowess_span_pts, ...
    spline_tension, min_frac_data, min_frac_overlap, low_res_spc, 1);

% compute exact solution at midpoint time...

%... deform initial grid
[xgrid, ygrid] = meshgrid(xx, yy);
[xgrid_defm, ygrid_defm] = test_piv_util_transform(tform, xgrid(:), ygrid(:), 1);
xgrid_defm = reshape(xgrid_defm, size(uu));
ygrid_defm = reshape(ygrid_defm, size(uu));

%... get displacements and thier location at midpoint time
u_tm = xgrid_defm-xgrid;
v_tm = ygrid_defm-ygrid;
x_tm = 0.5*(xgrid_defm+xgrid);
y_tm = 0.5*(ygrid_defm+ygrid);

% ... interpolate/extrapolate to image grid at midpoint time
uu_exact = nan(size(xgrid));
uu_exact(:) = spline2d(x_tm(:), y_tm(:), xgrid(:), ygrid(:), u_tm(:), 0.95);
vv_exact = nan(size(xgrid));
vv_exact(:) = spline2d(x_tm(:), y_tm(:), xgrid(:), ygrid(:), v_tm(:), 0.95);
    
% compute errors
uu_error = uu-uu_exact;
vv_error = vv-vv_exact;

% compute strain values
[displ, ~, ~, Dd, ~, ~, ~, ~] = ...
    deformation(xgrid, ygrid, uu, vv, ~isnan(uu));

% print and plot standard results
test_piv_util_print_error(uu_error, vv_error);
test_piv_util_plot_error(uu_error, vv_error);
test_piv_util_plot(xx, yy, uu, vv, displ, Dd);
