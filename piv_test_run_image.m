function [] = piv_test_run_image()
%
% Run a hard-coded test case using a synthetic image pair as generated by
% piv_test_create_image.
%
% %

%% parameters

% image parameters
tform = [1, 0, 0;  
         0, 1, 0];
bnd_mean = 0.7;
bnd_ampl = 0.2;
bnd_freq = 1;

% piv parameters
samplen = 30;
sampspc = 30;
intrlen = 100;
npass = 1;
valid_max = 2;
valid_eps = 0.01;

%% generate test images

[ini, fin, ini_roi, fin_roi, xx, yy] = ...
    piv_test_create_image(tform, bnd_mean, bnd_ampl, bnd_freq);

% standard preprocessing steps



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