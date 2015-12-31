function [xx, yy, uu, vv] = ...
    yalebox_piv(ini, fin, ini_roi, fin_roi, xx, yy, samplen, sampspc, ...
        intrlen, npass, valid_max, valid_eps, verbose)                 
% New implementation PIV analysis for Yalebox image data
%
% Arguments, input:
%
%   ini, fin = 2D matrix, double, range 0 to 1, normalized grayscale image from
%       the start and end of the step to be analyzed.
%
%   ini_roi, fin_roi = 2D matrix, logical, mask indicating pixels where there is
%       sand (1) and where there is only background (0) that should be ignored.
%
%   xx = Vector, double, increasing, x-direction coordinate vector, length
%       must match the columns in ini and fin.
%
%   yy = Vector, double, increasing, y-direction coordinate vector, length
%       must match the rows in ini and fin.
%
%   samplen = Vector, length == number of grid resolutions, integer, side
%       length of the square sample window
%
%   sampspc = Vector, length == number of grid resolutions, integer,
%       spacing between adjacent sample points in the (square) sample grid
%
%   intrlen = Vector, length == number of grid resolutions, integer, side
%       length of the square interrogation window
%
%   npass = Vector, length == number of grid resolutions, integer, number of
%       image deformation passes
%
%   valid_max = Scalar, double, maximum value for the normalized residual
%       in the vector validation function, above which a vector is flagged
%       as invalid. Ref [3] reccomends a value of 2.
%
%   epsilon = Scalar, double, minumum value of the normalization factor in
%       the vector validation function. Ref [3] reccomends a value of 0.1.
%
%   verbose = Scalar, integer, flag to enable (1) or diasable (0) verbose text
%       output messages
%
% Arguments, output:
%
%   xx, yy = Vector, double, coordinate vectors for the final output sample
%       grid, in world coordinate units
%
%   uu, vv = 2D matrix, double, computed displacement in the x- and y-directions
%       in world coordinate units
%
% References:
%
% [1] Raffel, M., Willert, C. E., Wereley, S. T., & Kompenhans, J. (2007).
%   Particle Image Velocimetry: A Practical Guide. BOOK. 
%
% [2] Wereley, S. T. (2001). Adaptive Second-Order Accurate Particle Image
%   Velocimetry, 31
%
% [3] Westerweel, J., & Scarano, F. (2005). Universal outlier detection for PIV
%   data. Experiments in Fluids, 39(6), 1096???1100. doi:10.1007/s00348-005-0016-6

% local parameters
min_frac_data = 0.5;
min_frac_overlap = min_frac_data/2;

% parse inputs
check_input(ini, fin, ini_roi, fin_roi, xx, yy, samplen, sampspc, intrlen, ...
    npass, valid_max, valid_eps, verbose);

% expand grid definition vectors to reflect the number of passes
[samplen, intrlen, sampspc] = expand_grid_def(samplen, intrlen, sampspc, npass);

% init full-resolution grids
cc_full = 1:size(ini, 2);
rr_full = 1:size(ini, 1);
[cc_full_grid, rr_full_grid] = meshgrid(cc_full, rr_full);
uu_full = zeros(size(ini));
vv_full = zeros(size(ini));

% init sample grids 
[rr, cc] = yalebox_piv_sample_grid(samplen(1), sampspc(1), size(ini));
nr = length(rr);
nc = length(cc);
uu = zeros(nr, nc); 
vv = zeros(nr, nc); 

% multipass loop
np = length(samplen);
for pp = 1:np-1
    
    % deform images
    defm_ini = imwarp(ini, -cat(3, uu_full, vv_full)/2, ...
        'cubic', 'FillValues', 0);    
    defm_fin = imwarp(fin,  cat(3, uu_full, vv_full)/2, ...
        'cubic', 'FillValues', 0);
   
    % deform roi masks, and re-apply to clean up edge artefacts from warping
    roi_epsilon = 1e-2; % numerical precision for roi deformation
    tmp = imwarp(double(ini_roi), -cat(3, uu_full, vv_full)/2, ...
        'cubic', 'FillValues', 0);
    defm_ini_roi = abs(tmp-1) < roi_epsilon;
    defm_ini(~defm_ini_roi) = 0;
    
    tmp = imwarp(double(fin_roi), cat(3, uu_full, vv_full)/2, ...
        'cubic', 'FillValues', 0);
    defm_fin_roi = abs(tmp-1) < roi_epsilon;
    defm_fin(~defm_fin_roi) = 0;
    
    % all grid points start in the ROI
    roi = true(nr, nc);
    
    % set subpixel correlation value matrix to zero
    cval = zeros(nr, nc);
    
    % reset data centroid grids
    rr_cntr = zeros(nr, nc);
    cc_cntr = zeros(nr, nc);
    
    % determine the minimum number of overlapping pixels for valid xcr 
    min_overlap = min_frac_overlap*samplen(pp)*samplen(pp);
    
    % debug: keep track of per-pass delta-displacements {
    duu = zeros(nr, nc);
    dvv = zeros(nr, nc);
    % } debug
    
    % sample grid loops
    for jj = 1:nc
        for ii = 1:nr
            
            % get sample and (offset) interrogation windows
            [samp, samp_pos, frac_data, rr_cntr(ii,jj), cc_cntr(ii,jj)] = ...
                yalebox_piv_window(defm_ini, rr(ii), cc(jj), samplen(pp));
            
            [intr, intr_pos] = ...
                yalebox_piv_window(defm_fin, rr(ii), cc(jj), intrlen(pp));
            
            % skip and remove from ROI if sample window is too empty
            if frac_data < min_frac_data
                fprintf('SKIP: frac_data = %f, ii = %i, jj = %i\n', ...
                    frac_data, ii, jj);
                roi(ii, jj) = false;
                uu(ii, jj) = NaN;
                vv(ii, jj) = NaN;
                continue
            end
            
            % compute normalized cross-correlation
            % xcr = normxcorr2(samp, intr);            
            [xcr, overlap] = normxcorr2_masked(intr, samp, intr~=0, samp~=0);
            xcr = xcr.*double(overlap>min_overlap);

            % find correlation plane max, subpixel precision
            [rpeak, cpeak, val, stat] = yalebox_piv_peak_gauss2d(xcr);
            % [rpeak, cpeak, stat] = peak_optim_fourier(xcr);
            if stat == false
                uu(ii, jj) = NaN;
                vv(ii, jj) = NaN;
                continue
            end
            
            % find displacement from position of the correlation max
            %   - account for padding in cross-correlation (-samplen(gg))
            %   - account for relative position of interogation and sample
            %     windows (e,g, for columns: -(samp_pos(1)-intr_pos(1))
            delta_uu = cpeak-samplen(pp)-(samp_pos(1)-intr_pos(1));
            delta_vv = rpeak-samplen(pp)-(samp_pos(2)-intr_pos(2));
            
            % debug: keep track of per-pass delta-displacements {
            duu(ii,jj) = delta_uu; 
            dvv(ii,jj) = delta_vv;
            % } debug
            
            uu(ii, jj) = uu(ii, jj)+delta_uu;
            vv(ii, jj) = vv(ii, jj)+delta_vv;
            cval(ii, jj) = val;
             
        end % ii
    end % jj
    % end sample grid loops
   
    % get next sample grid (last loop repeats same)    
    [rr, cc] = yalebox_piv_sample_grid(samplen(pp+1), sampspc(pp+1), size(ini));
    nr = length(rr);
    nc = length(cc);    
    [cc_grid, rr_grid] = meshgrid(cc, rr);
    
    % find and drop invalid displacement vectors
    valid = yalebox_piv_valid_nmed(uu, vv, roi, valid_max, valid_eps);
    keep = valid & roi;
    
    % interpolate/extrapolate/smooth displacements to next sample grid
%     interp_method = 'tpaps';
    interp_method = 'tspline';
%     interp_method = 'lowess';

    % debug: keep original data
    uu0 = uu; % uu0(~roi) = NaN;
    vv0 = vv; % vv0(~roi) = NaN;
    
    figure
    subplot(1,2,1); imagesc(uu0); subplot(1,2,2); imagesc(vv0)
    pause
    % NOTE: uu0 and vv0 are fully populated in 2nd pass 
    % THIS MAY BE IMPORTANT -- IS MASKING WORKING OR NOT?
    % IT IS, THE POPULATED VALUES COME FROM PREVIOUS PASSES WHICH INTERPOLATE TO THE FULL GRID
    % NOT SURE IF THIS WOULD HAVE A NEGATIVE IMPACT...
    
    switch interp_method
        
        % TPAPS: interpolation and smoothing
        case 'tpaps'
            
            % smoothing parameter
            p = [];
            
            % get interpolant
%             xy_in = [cc_cntr(keep)'; rr_cntr(keep)'];
            xy_in = [cc_grid(keep)'; rr_grid(keep)'];            
            uv_in = [uu(keep)'; vv(keep)'];
            [st, p] = tpaps(xy_in, uv_in, p);
            
            % evaluate for sample grid
            xy_out = [cc_grid(:)'; rr_grid(:)'];
            uv_out = fnval(st, xy_out);            
            uu = reshape(uv_out(1,:), nr, nc);
            vv = reshape(uv_out(2,:), nr, nc);
            
            % test: load exact full values for full grid displacements {
            load('full.mat');
            % } test
            
%             % evaluate for full resolution grid
%             xy_out = [cc_full_grid(:)'; rr_full_grid(:)'];
%             uv_out = fnval(st, xy_out);            
%             uu_full = reshape(uv_out(1,:), size(ini));
%             vv_full = reshape(uv_out(2,:), size(ini));
            
            fprintf('TPAPS smoothing parameter = %f\n', p);            
            
        % TSPLINE: interpolation, no smoothing
        case 'tspline'
            
            % tension parameter
            t = 0.95;

            % sample grid
            uu = spline2d(cc_grid(:), rr_grid(:), cc_cntr(keep), rr_cntr(keep), ...
                uu(keep), t);
            uu = reshape(uu, size(cc_grid));
            vv = spline2d(cc_grid(:), rr_grid(:), cc_cntr(keep), rr_cntr(keep), ...
                vv(keep), t);
            vv = reshape(vv, size(cc_grid));
            
%             % test: load exact full values for full grid displacements {
%             load('full.mat');
%             % } test
            
            % full resolution
            uu_full = spline2d(cc_full_grid(:), rr_full_grid(:), cc_cntr(keep), rr_cntr(keep), ...
                uu(keep), t);
            uu_full = reshape(uu_full, size(ini));
            vv_full = spline2d(cc_full_grid(:), rr_full_grid(:), cc_cntr(keep), rr_cntr(keep), ...
                vv(keep), t);
            vv_full = reshape(vv_full, size(ini));
            
        case 'lowess'
            
            fit_opt = fitoptions('lowess', 'Robust', 'LAR', 'Span', 0.05);
            
            uu_fit = fit([cc_cntr(keep), rr_cntr(keep)], uu(keep), ...
                'lowess', fit_opt);
            vv_fit = fit([cc_cntr(keep), rr_cntr(keep)], vv(keep), ...
                'lowess', fit_opt);
            
            uu = reshape(uu_fit(cc_grid(:), rr_grid(:)), nr, nc);
            vv = reshape(vv_fit(cc_grid(:), rr_grid(:)), nr, nc);
            
%             % test: load exact full values for full grid displacements {
%             load('full.mat');
%             % } test
            
            vv_full = reshape(vv_fit(cc_full_grid(:), rr_full_grid(:)), size(ini));
            uu_full = reshape(uu_fit(cc_full_grid(:), rr_full_grid(:)), size(ini));
           
        otherwise
            error('invalid smoothing method');
    end
    
%     % debug: plot the effect of interpolation/smoothing {
%     figure 
%     subplot(1,2,1); imagesc(uu-uu0); colorbar; title(sprintf('uu-uu0, pass %i', pp));
%     subplot(1,2,2); imagesc(vv-vv0); colorbar; title(sprintf('vv-vv0, pass %i', pp));
%     pause
%     % } debug

    % compute errors by interpolating onto the exact full grid
    E = load('full.mat');
    
    uu_cntr_exact = interp2(cc_full_grid, rr_full_grid, E.uu_full, cc_cntr, rr_cntr);
    
    uu_grid_exact = interp2(cc_full_grid, rr_full_grid, E.uu_full, cc_grid, rr_grid);
    
    uu_cntr_err = uu_cntr_exact-uu0; 
    
    uu_grid_err = uu_grid_exact-uu; 
    
%     figure
%     subplot(1,2,1); imagesc(uu_cntr_err); title('uu\_cntr\_err'); colorbar
%     subplot(1,2,2); imagesc(uu_grid_err); title('uu\_grid\_err'); colorbar
%     linkaxes

    
end
% end multipass loop

% % delete points outside the ROI
% uu(~roi) = NaN;
% vv(~roi) = NaN;

% convert displacements to world coordinates (assumes constant grid spacing)
uu = uu.*(xx(2)-xx(1));
vv = vv.*(yy(2)-yy(1));

% interpolate world coordinates for displacement vectors
xx = interp1(1:size(ini,2), xx, cc, 'linear', 'extrap');
yy = interp1(1:size(ini,1), yy, rr, 'linear', 'extrap');

% % debug {
% keyboard
% % } debug

end

%% subroutines

function [slen_ex, ilen_ex, sspc_ex] = expand_grid_def(slen, ilen, sspc, np)
%
% Expand the grid definition vectors to include the correct number of passes for
% each grid. Input arguments are defined above, but use shortened names here:
% samplen -> slen, intrlen -> ilen, sampspc -> sspc, npass -> np. 
%
% Note: outputs are intentionally not preallocated - these vectors are small and
% the performace cost is negligible. 
% %

slen_ex = [];
ilen_ex = [];
sspc_ex = [];

for ii = 1:length(np)
   slen_ex = [slen_ex, repmat(slen(ii), 1, np(ii))]; %#ok!
   ilen_ex = [ilen_ex, repmat(ilen(ii), 1, np(ii))]; %#ok!
   sspc_ex = [sspc_ex, repmat(sspc(ii), 1, np(ii))]; %#ok!
end

% repeat the last element to simplify interpolation code for the final pass
slen_ex(end+1) = slen_ex(end);
ilen_ex(end+1) = ilen_ex(end);
sspc_ex(end+1) = sspc_ex(end);

end

function [] = check_input(ini, fin, ini_roi, fin_roi, xx, yy, samplen, ...
    sampspc, intrlen, npass, valid_max, valid_eps, verbose)
%
% Check for sane input argument properties, exit with error if they do not
% match expectations.
% %

[nr, nc] = size(ini); % image size
ng = numel(samplen); % number of grid refinement steps

validateattributes(ini, {'double'}, {'2d', 'real', 'nonnan', '>=', 0, '<=' 1});
validateattributes(fin, {'double'}, {'2d', 'real', 'nonnan', '>=', 0, '<=' 1, ...
    'size', [nr, nc]});
validateattributes(ini_roi, {'logical'}, {'2d', 'size', [nr, nc]});
validateattributes(fin_roi, {'logical'}, {'2d', 'size', [nr, nc]});
validateattributes(xx, {'double'}, {'vector', 'real', 'nonnan', 'numel', nc});
validateattributes(yy, {'double'}, {'vector', 'real', 'nonnan', 'numel', nr});
validateattributes(samplen, {'numeric'}, {'vector', 'integer', 'positive', ...
    'nonnan'});
validateattributes(sampspc, {'numeric'}, {'vector', 'numel', ng, 'integer', ...
    'positive', 'nonnan'});
validateattributes(intrlen, {'numeric'}, {'vector', 'numel', ng, 'integer', ...
    'positive', 'nonnan'});
validateattributes(npass, {'numeric'}, {'vector', 'numel', ng, 'integer', ...
    'positive'});
validateattributes(valid_max, {'double'}, {'scalar', 'positive'});
validateattributes(valid_eps, {'double'}, {'scalar', 'positive'});
validateattributes(verbose, {'numeric', 'logical'}, {'scalar', 'binary'});

end

function [] = print_sep(msg)
% Print a user-specified message and a separator line for verbose output
% messages

fprintf('----------\n%s\n', msg);

end

function print_input(ini, fin, xx, yy, samplen, sampspc, intrlen, ...
                     npass, valid_max, valid_eps)
% Display values (or a summary of them) for the input arguments

fprintf('ini: size = [%i, %i], fraction data = %.2f%%\n',...
    size(ini, 1), size(ini, 2), sum(ini(:) ~= 0)/numel(ini)*100);

fprintf('fin: size = [%i, %i], fraction data = %.2f%%\n',...
    size(fin, 1), size(fin, 2), sum(fin(:) ~= 0)/numel(fin)*100);

fprintf('xx: length = %i, min = %.3f, max = %.3f, delta = %.3f\n', ...
    length(xx), min(xx), max(xx), xx(2)-xx(1));

fprintf('yy: length = %i, min = %.3f, max = %.3f, delta = %.3f\n', ...
    length(yy), min(yy), max(yy), yy(2)-yy(1));

fprintf('samplen: %s\n', sprintf('%i  ', samplen));

fprintf('sampspc: %s\n', sprintf('%i  ', sampspc));

fprintf('intrlen: %s\n', sprintf('%i  ', intrlen));

fprintf('npass: %i\n', npass);

fprintf('valid_max: %f\n', valid_max);

fprintf('valid_eps: %f\n', valid_eps);

end

function show_win(img0, img1, rcnt, ccnt, swin, spos, iwin, ipos) %#ok!
% function show_win(img0, img1, rcnt, ccnt, swin, spos, iwin, ipos)
%
% Display the sample and interrogation windows, as well as their position
%
% Arguments:
%
%   img0, img1 = 2D matrix, double, initial and final images
%
%   swin, iwin = 2D matrix, double, sample and interrogation windows
%
%   spos, ipos = Vector, length == 4, integer, position vectors for sample
%       and interrogation windows, formatted as [left, bottom, width,
%       height] in pixel coordinates
% %

% init figure
clim = [min(img0(:)), max(img0(:))];
set(gcf, 'units', 'normalized', 'position', [0.05, 0.05, 0.9, 0.9]);

% plot initial image with window positions superimposed
subplot(2, 2, 1);
imagesc(img0);
set(gca, 'YDir', 'normal');
caxis(clim);
hold on
plot(ccnt, rcnt, 'Color', 'k', 'Marker', '.')
plot([spos(1), spos(1)+spos(3)-1, spos(1)+spos(3)-1, spos(1)          , spos(1)], ...
     [spos(2), spos(2)          , spos(2)+spos(4)-1, spos(2)+spos(4)-1, spos(2)], ...
     'Color', 'k', 'LineWidth', 2, 'LineStyle', '-');
plot([ipos(1), ipos(1)+ipos(3)-1, ipos(1)+ipos(3)-1, ipos(1)          , ipos(1)], ...
     [ipos(2), ipos(2)          , ipos(2)+ipos(4)-1, ipos(2)+ipos(4)-1, ipos(2)], ...
     'Color', 'k', 'LineWidth', 2, 'LineStyle', '--');
title('initial image');
legend({'center', 'sample', 'interrogation'}, 'Location', 'NorthEast');
hold off
axis equal
axis tight

% plot final image with window positions superimposed
subplot(2, 2, 2);
imagesc(img1);
set(gca, 'YDir', 'normal');
caxis(clim);
hold on
plot(ccnt, rcnt, 'Color', 'k', 'Marker', '.')
plot([spos(1), spos(1)+spos(3)-1, spos(1)+spos(3)-1, spos(1)          , spos(1)], ...
     [spos(2), spos(2)          , spos(2)+spos(4)-1, spos(2)+spos(4)-1, spos(2)], ...
     'Color', 'k', 'LineWidth', 2, 'LineStyle', '--');
plot([ipos(1), ipos(1)+ipos(3)-1, ipos(1)+ipos(3)-1, ipos(1)          , ipos(1)], ...
     [ipos(2), ipos(2)          , ipos(2)+ipos(4)-1, ipos(2)+ipos(4)-1, ipos(2)], ...
     'Color', 'k', 'LineWidth', 2, 'LineStyle', '-');
title('final image');
legend({'center', 'sample', 'interrogation'}, 'Location', 'NorthEast');
hold off
axis equal
axis tight

% plot sample window
subplot(2, 2, 3);
imagesc(swin);
set(gca, 'YDir', 'normal');
caxis(clim);
title('sample window')
axis equal
axis tight
grid on

% plot interrogation window
subplot(2, 2, 4);
imagesc(iwin);
set(gca, 'YDir', 'normal');
caxis(clim);
title('interrogation window')
axis equal
axis tight
grid on
 
end

function [] = show_xcor(xcor, rpk, cpk) %#ok!
% plot correlation plane with the position of the peak

imagesc(xcor);
set(gca, 'YDir', 'normal');
caxis([-1 1]);
colorbar
hold on
plot(cpk, rpk, 'Color', 'k', 'Marker', '.')
title('cross-correlation');
hold off
axis equal
axis tight

end

function [] = show_valid(drop, uu, vv)
% display results from validation step

[ii_drop, jj_drop] = find(drop);
drop_nan = ones(size(drop));
drop_nan(drop) = NaN;

subplot(2,2,1)
title('uu')
imagesc(uu)
hold on
plot(jj_drop, ii_drop, '.w')
hold off

subplot(2,2,2)
title('vv')
imagesc(vv);
hold on
plot(jj_drop, ii_drop, '.w')
hold off

subplot(2,2,3)
title('uu drop')
imagesc(uu.*drop_nan)
hold on
plot(jj_drop, ii_drop, '.w')
hold off

subplot(2,2,4)
title('vv drop')
imagesc(vv.*drop_nan);
hold on
plot(jj_drop, ii_drop, '.w')
hold off

end
