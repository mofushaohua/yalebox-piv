% Test PIV parameters
%
% Expected variables:
%   PIV_PARAM_FILE: path to parameters definition file. Use
%       templates/piv.json as a starting point, and populate the variables
%       therein to suit your experiment.
%   IMAGES_FILE: path to pre-processed image file netCDF, as produced by
%       prep_series.m
%
% This script is designed to be run cell-by-cell. Each cell runs one step
% of the image preparation process. Run a cell, inspect the results, and
% edit the parameter file until you are satisfied with the results. Note
% that some cells depend on the results of previous cells.
% %

update_path('jsonlab', 'piv', 'util');

%% PIV analysis for single image pair -- edit parameter file to change

param = load_param(PIV_PARAM_FILE);

[xw, yw, ini, ini_mask, fin, fin_mask] = read_image_pair_from_nc(...
    IMAGES_FILE, ...
    param.test.ini.value, ...
    param.piv.gap.value);

piv_result = piv(...
    ini, ...
    fin, ...
    ini_mask, ...
    fin_mask, ...
    xw, ...
    yw, ...
    param.piv.samp_len.value, ...
    param.piv.samp_spc.value, ...
    param.piv.intr_len.value, ...
    param.piv.num_pass.value, ...
    param.piv.valid_radius.value, ...
    param.piv.valid_max.value, ...
    param.piv.valid_eps.value, ...
    param.piv.min_frac_data.value, ...
    param.piv.min_frac_overlap.value, ...
    true);


% %% strain analysis for single image pair -- uses generic parameters
%     
% strain_result = post_strain(piv_result.x_grd(1,:), piv_result.y_grd(:,1), ...
%     piv_result.u_grd, piv_result.v_grd, piv_result.roi_grd, 'nearest');
% 
