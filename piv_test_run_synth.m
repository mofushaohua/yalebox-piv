function [] = piv_test_run_synth(force)
%
% Run a hard-coded test case using a synthetic image pair as generated by
% piv_test_create_synth.
%
% Arguments:
%
% force = Scalar, binary, flag indicating whether to force recomputing input
%   variables (1) or not (0). This is useful if the downstream code has changed,
%   but input parameters have not.
%
% %

%% parameters

% synthetic image parameters
img_size = [276, 383];
tform = [1, 0, 10;  
         0, 1, 10];
min_spc = 3;
prob_white = 0.5;
ampl_white = 1;
ampl_black = -1;
sigma = 3;
max_attempts = 1e2;
bnd_mean = 0.7;
bnd_ampl = 0.2;
bnd_freq = 1;

% piv parameters
samplen = 30;
sampspc = 15;
intrlen = 100;
npass = 1;
valid_max = 2;
valid_eps = 0.01;

% local parameters
data_file = 'test/synth.mat';
func_name = 'piv_test_run_synth';


%% parse arguments and set defaults

narginchk(0,1);
if nargin == 0 || isempty(force) 
    force = 0;
end

validateattributes(force, {'numeric'}, {'scalar', 'binary'});

%% generate (or load) test images

% check if defined parameters match saved parameters
try
    F = load(data_file, 'img_size', 'tform', 'min_spc', 'prob_white', ...
        'ampl_white', 'ampl_black', 'sigma', 'max_attempts', 'bnd_mean', ...
        'bnd_ampl', 'bnd_freq');
    same = all(F.img_size == img_size) && ...
        all(F.tform(:) == tform(:)) && ...
        F.min_spc == min_spc && ...
        F.prob_white == prob_white && ...
        F.ampl_white == ampl_white && ...
        F.ampl_black == ampl_black && ...
        F.sigma == sigma && ...
        F.max_attempts == max_attempts && ...
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
        piv_test_create_synth(img_size, tform, min_spc, prob_white, ...
            ampl_white, ampl_black, sigma, max_attempts, bnd_mean, ...
            bnd_ampl, bnd_freq);
    save(data_file, 'img_size', 'tform', 'min_spc', 'prob_white', ...
        'ampl_white', 'ampl_black', 'sigma', 'max_attempts', 'bnd_mean', ...
        'bnd_ampl', 'bnd_freq', 'ini', 'ini_roi', 'fin', 'fin_roi', 'xx', 'yy');
end

clear F

%% run PIV and analyze results

% run piv
[xx, yy, uu, vv] = yalebox_piv(ini, fin, ini_roi, fin_roi, xx, yy, samplen, ...
    sampspc, intrlen, npass, valid_max, valid_eps, 1);

% compute exact solution at output grid points
[xgrid, ygrid] = meshgrid(xx, yy);
[xgrid_defm, ygrid_defm] = piv_test_util_transform(tform, xgrid(:), ygrid(:), 1);
xgrid_defm = reshape(xgrid_defm, size(uu));
ygrid_defm = reshape(ygrid_defm, size(uu));

uu_exact = xgrid_defm-xgrid;
vv_exact = ygrid_defm-ygrid;

% compute errors
uu_error = uu-uu_exact;
vv_error = vv-vv_exact;

% compute strain values
[displ, ~, ~, Dd, ~, ~, ~, ~] = ...
    yalebox_decompose_step(xgrid, ygrid, uu, vv, ~isnan(uu));

% print and plot standard results
piv_test_util_print_error(uu_error, vv_error);
piv_test_util_plot_error(uu_error, vv_error);
piv_test_util_plot(xx, yy, uu, vv, displ, Dd);
