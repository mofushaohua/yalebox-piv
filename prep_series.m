% function [] = prep_series(output_file, image_path, image_names, verbose)
% function [] = prep_series(output_file, image_path, image_names, x, y, scale, ...
%                   offset, mask_manual, hue_lim, val_lim, entr_lim, entr_win, ...
%                   morph_open_rad, morph_erode_rad, nwin, verbose)
% 
% Create PIV input file for a given image series. Reads in the images,
% performs masking and color correction, and saves the results and metadata
% in a netCDF file.
%
% Arguments:
% 
%   output_file = String, filename of the netCDF input file to be created. 
%
%   image_path = String, path to folder containing the images.
%
%   image_names = Cell array of strings, cells must contain filenames for
%       successive images in the experiment image series. 
%
%   x, y, scale, offset = Output arguments from prep_world_coord().
%
%   mask_manual = Output argument from prep_mask_manual()
%
%   hue_lim, val_lim, entr_lim, entr_win, morph_open_rad, morph_erode_rad = Input 
%       arguments for prep_mask_auto()
%
%   nwin = Input argument from prep_intensity()
%
%   verbose = Logical flag, display verbose messages (1) or don't (0)
%
%   PIV input netCDF format:
%       dimensions: x, y, step
%       variables: mask_auto, mask_manual, x, y, step, intensity
%       attributes: all preprocessing parameters
%
% %
% 
% % check for sane arguments (pass-through arguments are checked in subroutines)
% narginchk(16, 16); 
% validateattributes(output_file, {'char'}, {'vector'});
% validateattributes(image_path, {'char'}, {'vector'});
% validateattributes(image_names, {'cell'}, {'vector'});
% 
% % check that all images exist and have the expected size and type
% nimage = numel(image_names);
% for i = 1:nimage
%     try
%         this_file = [image_path filesep image_names{i}];
%         info = imfinfo(this_file);
%         assert(info.Width == numel(x) && info.Height == numel(y), ...
%             sprintf('incorrect dimensions in image %s', this_file));
%         assert(info.BitDepth == 24, ...
%             sprintf('incorrect bit depth in image %s', this_file));
%     catch
%         error('unable to read image %i: %s', i, this_file);
%     end
% end

% DEBUG
output_file = 'junk.nc';

% create netcdf file
ncid = netcdf.create(output_file, 'NETCDF4');

% add global attributes 
netcdf.putAtt(ncid, netcdf.getConstant('GLOBAL'), 'prep_rectify_and_crop ctrl_xw', ctrl_xw);
netcdf.putAtt(ncid, netcdf.getConstant('GLOBAL'), 'prep_rectify_and_crop ctrl_yw', ctrl_yw);
netcdf.putAtt(ncid, netcdf.getConstant('GLOBAL'), 'prep_rectify_and_crop ctrl_xp', ctrl_xp);
netcdf.putAtt(ncid, netcdf.getConstant('GLOBAL'), 'prep_rectify_and_crop ctrl_yp', ctrl_yp);
netcdf.putAtt(ncid, netcdf.getConstant('GLOBAL'), 'prep_rectify_and_crop crop_xw', crop_xw);
netcdf.putAtt(ncid, netcdf.getConstant('GLOBAL'), 'prep_rectify_and_crop crop_yw', crop_yw);
netcdf.putAtt(ncid, netcdf.getConstant('GLOBAL'), 'prep_mask_auto entropy_len', entropy_len);
netcdf.putAtt(ncid, netcdf.getConstant('GLOBAL'), 'prep_mask_auto num_cluster', num_cluster);
for ii = 1:num_cluster
    netcdf.putAtt(ncid, netcdf.getConstant('GLOBAL'), sprintf('prep_mask_auto cluster_center_%d', ii), cluster_center(ii,:));
end
netcdf.putAtt(ncid, netcdf.getConstant('GLOBAL'), 'prep_intensity eql_len', eql_len);
     
% % create dimensions
% x_dimid = netcdf.defDim(ncid, 'x', numel(x));
% y_dimid = netcdf.defDim(ncid, 'y', numel(y));
% s_dimid = netcdf.defDim(ncid, 'step', numel(image_names));
% 
% % define variables and thier attributes, compression, and chunking
% dim_3d = [x_dimid, y_dimid, s_dimid];
% chunk_3d = [numel(x), numel(y), 1];
% dim_2d= [x_dimid, y_dimid];
% 
% x_varid = netcdf.defVar(ncid, 'x', 'NC_FLOAT', x_dimid);
% netcdf.putAtt(ncid, x_varid, 'long_name', 'horizontal position');
% netcdf.putAtt(ncid, x_varid, 'units', 'meters');
% 
% y_varid = netcdf.defVar(ncid, 'y', 'NC_FLOAT', y_dimid);
% netcdf.putAtt(ncid, y_varid, 'long_name', 'vertical position');
% netcdf.putAtt(ncid, y_varid, 'units', 'meters');
% 
% s_varid = netcdf.defVar(ncid, 'step', 'NC_SHORT', s_dimid);
% netcdf.putAtt(ncid, s_varid, 'long_name', 'step number');
% netcdf.putAtt(ncid, s_varid, 'units', '1');
% 
% i_varid = netcdf.defVar(ncid, 'intensity', 'NC_FLOAT', dim_3d);
% netcdf.putAtt(ncid, i_varid, 'long_name', 'normalized sand brightness');
% netcdf.putAtt(ncid, i_varid, 'units', '1');
% netcdf.defVarDeflate(ncid, i_varid, true, true, 1);
% netcdf.defVarChunking(ncid, i_varid, 'CHUNKED', chunk_3d);
% 
% ma_varid = netcdf.defVar(ncid, 'mask_auto', 'NC_BYTE', dim_3d);
% netcdf.putAtt(ncid, ma_varid, 'long_name', 'sand mask, automatic');
% netcdf.putAtt(ncid, ma_varid, 'units', 'boolean');
% netcdf.defVarDeflate(ncid, ma_varid, true, true, 1);
% netcdf.defVarChunking(ncid, ma_varid, 'CHUNKED', chunk_3d);
% 
% mm_varid = netcdf.defVar(ncid, 'mask_manual', 'NC_BYTE', dim_2d);
% netcdf.putAtt(ncid, mm_varid, 'long_name', 'sand mask, manual');
% netcdf.putAtt(ncid, mm_varid, 'units', 'boolean');
% netcdf.defVarDeflate(ncid, mm_varid, true, true, 1);

% finish netcdf creation
netcdf.endDef(ncid);
netcdf.close(ncid);

% % populate constant variables
% ncid = netcdf.open(output_file, 'WRITE');
% netcdf.putVar(ncid, x_varid, x);
% netcdf.putVar(ncid, y_varid, y);
% netcdf.putVar(ncid, s_varid, 0:nimage-1);
% netcdf.putVar(ncid, mm_varid, uint8(mask_manual'));
% netcdf.close(ncid);
% 
% % loop over all images
% for i = 1:nimage
%     
%     % read in original image
%     this_file = [image_path filesep image_names{i}];
%     rgb = imread(this_file);
%     hsv = rgb2hsv(rgb);    
%     
%     if verbose
%         fprintf('%s: %s\n', mfilename, this_file);
%     end
%     
%     % compute automatic mask
%     mask_auto = prep_mask_auto(hsv, hue_lim, val_lim, entr_lim, entr_win, ...
%         morph_open_rad, morph_erode_rad, false, verbose);
% 
%     % convert to normalized intensity
%     intensity = prep_intensity(hsv(:,:,3), mask_manual & mask_auto, nwin, ...
%         0, verbose);
%     
%     % save results
%     ncid = netcdf.open(output_file, 'WRITE');
%     netcdf.putVar(ncid, ma_varid, [0, 0, i-1], [numel(x), numel(y), 1], ...
%         uint8(mask_auto'));
%     netcdf.putVar(ncid, i_varid, [0, 0, i-1], [numel(x), numel(y), 1], ...
%         intensity');
%     netcdf.close(ncid);
%     
% end
