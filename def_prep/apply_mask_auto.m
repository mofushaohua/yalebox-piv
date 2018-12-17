function [] = apply_mask_auto(param_file, mrgb)
% Apply automatic image masking routine given specified parameters
% 
% Arguments:
%   param_file: string, path to parameter definition JSON file
%   mrgb: N x M x 3 matrix, RGB image with manual mask applied to it
% % 

param = loadjson(param_file, 'SimplifyCell', 1);

% apply auto masking and display results
prep_mask_auto(...
    mrgb, ...
    param.mask_auto.hue_lim.value,...
    param.mask_auto.value_lim.value, ...
    param.mask_auto.entropy_lim.value, ...
    param.mask_auto.entropy_len.value, ...
    param.mask_auto.morph_open_rad.value, ...
    param.mask_auto.morph_erode_rad.value, ...
    true, ...
    true);
