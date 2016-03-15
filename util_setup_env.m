% MATLAB script to add dependencies for the Yalebox PIV project.


top_dir = fileparts(which(mfilename));
addpath(top_dir);

dep_dir = fullfile(top_dir, 'depend');
addpath(genpath(dep_dir));