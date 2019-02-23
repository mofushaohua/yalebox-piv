function mask = prep_mask_apply(rgb, model, show)
% function mask = prep_mask_apply(rgb, model, show)
% 
% Apply trained classifier and morphological clean-up to create a
% sand/other mask array
% 
% Arguments:
%   rgb: 3D matrix, RGB 24-bit image
% 
%   model: ML model class, trained classifier
% 
%   show: set true to display resulting masked image for inspection, or
%       (default) false to skip the plot
% 
% Returns:
%   mask: 2D matrix, 1 where sand, 0 where other
% % 

% TODO: add log messages
% TODO: post process the mask with morph filters (like before)

% set defaults
if nargin < 3; show = false; end

% sanity checks
narginchk(2, 3);
validateattributes(rgb, {'numeric'}, {'3d'});
% TODO: validate model arg
validateattributes(show, {'logical'}, {'scalar'});

% predict
X = prep_mask_features(rgb);
labels = predict(model, X);
if iscell(labels)
    % random forest models return silly cell arrays, conver to numeric
    labels = double(cell2mat(labels));
    labels(labels == double('1')) = true;
    labels(labels == double('0')) = false;
end
labels = reshape(labels, size(rgb, 1), size(rgb, 2));
mask = logical(labels);

% fill holes along edges (wall off one corner, fill, repeat)
ridx = 1:size(mask, 1);
cidx = 1:size(mask, 2);
dr = [1, 1, 0, 0];
dc = [1, 0, 0, 1];
for ii = 1:4
    wall = true(size(mask)+1);
    wall(ridx+dr(ii), cidx+dc(ii)) = mask;
    wall = imfill(wall, 'holes');
    mask = wall(ridx+dr(ii), cidx+dc(ii));
end

% extract largest connected object
object_label = bwlabel(mask);
largest_object = mode(object_label(object_label>0));
mask = object_label == largest_object;

% clean up edges with morphological filters
mask = imopen(mask, strel('disk', 3));
mask = imclose(mask, strel('disk', 30));

% display
if show
    hf = figure
    hf.Name = 'Masking Results';
    
    hax1 = subplot(2, 1, 1);
    imagesc(rgb, 'AlphaData', mask);
    axis equal tight
    hax1.Color = [1.0, 0.25, 0.25];
    hax1.YDir = 'normal';
    
    hax2 = subplot(2, 1, 2);
    imagesc(rgb, 'AlphaData', ~mask);
    axis equal tight
    hax2.Color = [1.0, 0.25, 0.25];
    hax2.YDir = 'normal';
    
    linkaxes([hax1, hax2], 'xy');
end