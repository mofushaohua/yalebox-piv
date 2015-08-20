function [] = yalebox_piv_series(input_file, output_file, npass, win, spc, ...
                    max_u_pos, max_u_neg, max_v_pos, max_v_neg, validate, ...
                    eps_0, eps_thresh, min_sand_frac, intra_pair_step, ...
                    inter_pair_step, view)
%
% Run yalebox-piv analysis on all frames in the input netcdf file, saving
% results to the output netcdf file. This function acts as a wrapper for
% yalebox_piv(), which estimates displacement vectors from image pairs.
%
% Arguments:
% 
% npass = Scalar, integer. Number of PIV passes.
%
% win = Vector, length == npass, integer, width of sample window for each
%   pass, units: [pixels].
%
% spc = Vector, length == npass, integer, distance between samples for each
%   pass, units: [pixels]. Note that if spc == win the sample windows do
%   not overlap or have gaps between them.
%
% max_u_pos = Vector, length == npass, maximum displacement for each pass 
%   in the positive x-direction, units = [m]
%
% max_u_neg = Vector, length == npass, " " negative x-direction " "
%
% max_v_pos = Vector, length == npass, " " positive y-direction " "
%
% max_v_neg = Vector, length == npass, " " negative y-direction " "
%
% validate = Scalar, logical, flag to enable (true) or disable (false) vector 
%   validation/interpolation
%
% eps_0 = Scalar, double, parameter to normalized median filter used for vector 
%   validation, ignored if validate == false;
%
% eps_thresh = Scalar, double  " "
%
% min_sand_frac = Scalar, double. Minimum fraction of sample window that must contain 
%   sand to proceed with PIV
%
% intra_pair_step = Integer.  Step between images in the same pair (1=adjacent) 
%
% inter_pair_step = Integer.  Step between image pairs (1=adjacent) 
%
% view = String. Select 'side' or 'top' view.
 

% Keith Ma, August 2015

% % DEBUG: DISABLED FOR SPEED
% % get input file checksum using system utility sha256sum
% [~, tmp] = system(sprintf('sha256sum %s', input_file));
% tmp = strsplit(tmp);
% in.chksum = tmp{1};
in.chksum = 'DEBUG';

% open input file, get ids
in.ncid = netcdf.open(input_file, 'NOWRITE');
in.dataid = netcdf.inqVarID(in.ncid, 'intensity');
in.xid = netcdf.inqVarID(in.ncid, 'x');
in.yid = netcdf.inqVarID(in.ncid, 'y');
in.sid = netcdf.inqVarID(in.ncid, 'step');

% get input coordinate vectors
in.x = netcdf.getVar(in.ncid, in.xid);
in.y = netcdf.getVar(in.ncid, in.yid);
in.s = netcdf.getVar(in.ncid, in.sid);

% create output file
out.ncid = netcdf.create(output_file, 'NETCDF4');

% write global attributes
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv_series:input_file', input_file);
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv_series:input_file:sha256sum', in.chksum);
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv:npass', npass);
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv:win:pixels', win);
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv:spc:pixels', spc);
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv:max_u_pos:pixels', max_u_pos);
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv:max_u_neg:pixels', max_u_neg);
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv:max_v_pos:pixels', max_v_pos);
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv:max_v_neg:pixels', max_v_neg);
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv:validate', double(validate));
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv:eps_0', eps_0);
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv:eps_thresh', eps_thresh);
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv:min_sand_frac', min_sand_frac);
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv_series:intra_pair_step', intra_pair_step);
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv_series:inter_pair_step', inter_pair_step);
netcdf.putAtt(out.ncid, netcdf.getConstant('GLOBAL'),...
    'yalebox_piv:view', view);

% loop: analyze each image pair

% finalize files
netcdf.close(in.ncid);
netcdf.close(out.ncid);

% 
% params.S = S;
% params.SPC = SPC;
% params.ML = ML;
% params.MR = MR;
% params.MU = MU;
% params.MD = MD;
% params.CBC = CBC;
% params.validate_nmed = validate_nmed;
% params.epsilon0 = epsilon0;
% params.epsilonthresh = epsilonthresh;
% params.validate_nstd = validate_nstd;
% params.nstd = nstd;
% params.maskfrac = maskfrac;
% params.view = view;
%   
% % loop: call PIV, save results
% nim = numel(imfilenames);
% count = 0;
% nsteps = numel(1:interpairstep:nim-intrapairstep);
% for i = 1:interpairstep:nim-intrapairstep
% 
%     count = count+1;
%     params.IM = imfilenames([i,i+intrapairstep]);
%     
%     fprintf('\nRUNPIVSERIES: step %i of %i\n',count,nsteps);
%     [x,y,u,v,cval,mask] = sandboxpiv(params);
%     
%     save(sprintf('%s%03i.mat',savename,count),'params','x','y','u','v','cval','mask');
%     
% end
% 
% % end
