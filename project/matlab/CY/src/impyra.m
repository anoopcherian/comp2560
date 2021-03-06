function pyra = impyra(im, model, net, upS)
% Compute feature pyramid.
%
% pyra.feat{i} is the i-th level of the feature pyramid.
% pyra.scales{i} is the scaling factor used for the i-th level.
% pyra.feat{i+interval} is computed at exactly half the resolution of feat{i}.
% first octave halucinates higher resolution data.
cnnpar = model.cnn;
psize = cnnpar.psize;
if isfield(cnnpar, 'mean_pixel')                    % for compatible
    mean_pixel = single(cnnpar.mean_pixel);
    mean_pixel = permute(mean_pixel(:), [3,2,1]);
else
    mean_pixel(1,1,:) = single([128,128,128]);
end

im = single(imresize(im,upS));  % may upscale image to better handle small objects.

step = cnnpar.step;

% interval between scale x and scale 2 * x
interval = model.interval;

% psize is the size of the window which we convolve over the image (the
% first CNN layer); padx and pady ensure that (width + padx) / step is an
% integer---typically padx and pady are tiny.
padx      = max(ceil((double(psize(1)-1)/2)),0); % more than half is visible
pady      = max(ceil((double(psize(2)-1)/2)),0); % more than half is visible
% how much we increase the scale by at each iteration
sc = 2 ^(1/interval);
imsize = [size(im, 1), size(im, 2)];
max_scale = 1 + floor(log(min(imsize)/max(psize))/log(sc));

% pyra is structure
pyra = struct('feat', cell(max_scale,1), 'sizs', cell(max_scale,1), 'scale', cell(max_scale, 1), ...
    'padx', cell(max_scale,1), 'pady', cell(max_scale,1));

% ibatch tells us how big our batch size for forward propagation is; each
% input in a batch will be the size of the largest input in that batch
% (which wastes a lot of pixel volume)
ibatch = interval;    % use smaller ibatch if out of memory
for i = 1:ibatch:max_scale
    scaled = imresize(im, 1/sc^(i-1));
    
    num = min(ibatch, max_scale-i+1);
    impyra = zeros(size(scaled,1)+2*padx, size(scaled,2)+2*pady, 3, num, 'single');
    
    % This resizing step is basically free compared to the convolution cost
    for n = 0:num-1
        % the image
        scaled_pad = padarray(scaled, [padx, pady, 0], 'replicate');
        scaled_pad = bsxfun(@minus, scaled_pad, mean_pixel);
        impyra(1:size(scaled_pad,1), 1:size(scaled_pad,2),:,n+1) = scaled_pad;
        % output size
        pyra(i+n).sizs = floor([size(scaled_pad,1)-psize(1), size(scaled_pad,2)-psize(2)] / step) + 1;      % caffe -> ceil
        
        pyra(i+n).scale = step ./ (upS * 1/sc^(i-1+n));
        pyra(i+n).pady = pady / step;
        pyra(i+n).padx = padx / step;
        scaled = imresize(scaled, 1/sc);
    end
    
    % Convolution is by far the most costly step
    % TODO: Do we have the dimension ordering here? matcaffe code said
    % something about h * w * c * n (which is super weird)
    % Reshaping the data blob to match our input size will ensure that
    % forward() works later. Caffe resizes subsequent layers on-the-fly,
    % only re-allocating memory if it needs to (I don't think it ever frees
    % anything).
    data_blob = net.blobs('data');
    data_blob.reshape(size(impyra));
    % input is a cell array because some nets have multiple input layers,
    % as opposed to input blobs (ours doesn't)
    resp = net.forward({impyra});      % softmax apply in caffe model.
    
    % Believe it or not, resp{1} is HUGE, so the time taken to copy things
    % back out is on the same order as the time taken to copy them in!
    % Example: 20s for forward conv, followed by 5s of copying!
    for n = 0:num-1
        pyra(i+n).feat = resp{1}(1:pyra(i+n).sizs(1), 1:pyra(i+n).sizs(2), :, n+1);
    end
end