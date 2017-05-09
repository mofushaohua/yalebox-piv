function [] = piv_series_standalone(image_file, param_file, piv_file)
% function [] = piv_series_standalone(param_file)
%
% Wrapper function to run piv_series() as a compiled standalone executable.
% Includes special configuration needed to run on the BU SCC cluster batch
% system.
%
% Arguments:
%   image_file: String, netCDF file containing pre-processed image series, as
%       produced by prep_series()
%   param_file: String, .MAT file containing all piv_series() input arguments,
%       typically produced using a customized version of
%       piv_get_param_template.m
%   piv_file: String, netCDF file to write PIV results, will *not* overwrite
% % 

% initialize parallel environment
% NOTE: use existing pool if possible, faster for interactive development
if isempty(gcp('nocreate')) 
    if getenv('ENVIRONMENT')
        % SCC: avoid use of remote disk and use only requested number of cores
        fprintf('%s: Init parallel environment for SCC\n', mfilename);
        cluster = parcluster('local');
        cluster.JobStorageLocation = getenv('TMPDIR');
        nslots = str2double(getenv('NSLOTS'));
        parpool(cluster, nslots);
    else
        % not SCC: use default settings
        fprintf('%s: Init default parallel environment\n', mfilename);
        parpool();
    end
end

% run PIV analysis
args = load(param_file);
piv_series(piv_file, image_file, args.step_range, args.gap, args.samp_len, ...
    args.samp_spc, args.intr_len, args.num_pass, args.valid_radius, ...
    args.valid_max, args.valid_eps, args.spline_tension, args.min_frac_data, ...
    args.min_frac_overlap, true);
