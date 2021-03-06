% set some configuration settings
function config = set_algo_parameters()
%% set the configuration parameters: You need to set this.

% set the cache for storing optical flow and pose candidates. You need a
% large disk space for this.
config.cache_path = './cache/';

% this is the place to store the pose candidates
config.data_store_path = [config.cache_path 'boxes_public1/']; % 

% this is the place where the video sequences are stored as frames, each
% sequence in a separate folder. If you use poses in the wild, then the
% path will be something like below.
config.data_path = './dataset/selected_seqs/';


% cache for storing a video of the detections, this might not be
% available in the  current package.
config.video_store_path = [config.cache_path 'video/'];

% cache for flow.
config.data_flow_path = [config.cache_path 'flow/'];

% MPII stuff
config.mpii_data_store_path = [config.cache_path 'boxes_public_mpii/']; % 
config.piw_data_store_path = [config.cache_path 'boxes_public_piw/']; % 
config.mpii_dest_path = './dataset/mpii/'; % where we store all MPII stuff
config.piw_dest_path = './dataset/piw/';
config.mpii_data_path = fullfile(config.mpii_dest_path, 'selected_seqs/');
config.piw_data_path = fullfile(config.piw_dest_path, 'selected_seqs/');
config.mpii_data_flow_path = [config.cache_path 'flow_mpii/'];
config.piw_data_flow_path = [config.cache_path 'flow_piw/'];
% for translating MPII cooking into PIW-like structure
config.mpii_trans_spec = struct(...
    'indices', {...
        ... MIDDLE:
        12,    ... Chin (head lower point)  #1
        ... LEFT:
        4,     ... Left shoulder            #2
        [4 6], ... Left upper arm           #3
        6,     ... Left elbow               #4
        [6 8], ... Left forearm             #5
        8,     ... Left wrist               #6
        ... RIGHT:
        3,     ... Right shoulder           #7
        [3 5], ... Right upper arm          #8
        5,     ... Right elbow              #9
        [5 7], ... Right forearm            #10
        7,     ... Right wrist              #11
        ... TORSO:
        1,     ... Torso upper point        #12
        2      ... Torso lower point        #13
    }, ...
    'weights', {...
        1,         ... Chin (head lower point)  #1
        1,         ... Left shoulder            #2
        [1/2 1/2], ... Left upper arm           #3
        1,         ... Left elbow               #4
        [1/2 1/2], ... Left forearm             #5
        1,         ... Left wrist               #6
        1,         ... Right shoulder           #7
        [1/2 1/2], ... Right upper arm          #8
        1,         ... Right elbow              #9
        [1/2 1/2], ... Right forearm            #10
        1,         ... Right wrist              #11
        1,         ... Torso upper              #12
        1,         ... Torso lower              #13
    });
config.piw_trans_spec = struct(...
    'indices', {...
        ... MIDDLE:
        1,     ... Chin (head lower point)  #1
        ... LEFT:
        2,     ... Left shoulder            #2
        [2 3], ... Left upper arm           #3
        3,     ... Left elbow               #4
        [3 4], ... Left forearm             #5
        4,     ... Left wrist               #6
        ... RIGHT:
        5,     ... Right shoulder           #7
        [5 6], ... Right upper arm          #8
        6,     ... Right elbow              #9
        [7 8], ... Right forearm            #10
        7,     ... Right wrist              #11
        ... TORSO: (fudged)
        8,     ... Torso upper point        #12
        8      ... Torso lower point        #13
    }, ...
    'weights', {...
        1,         ... Chin (head lower point)  #1
        1,         ... Left shoulder            #2
        [1/2 1/2], ... Left upper arm           #3
        1,         ... Left elbow               #4
        [1/2 1/2], ... Left forearm             #5
        1,         ... Left wrist               #6
        1,         ... Right shoulder           #7
        [1/2 1/2], ... Right upper arm          #8
        1,         ... Right elbow              #9
        [1/2 1/2], ... Right forearm            #10
        1,         ... Right wrist              #11
        1,         ... Torso upper              #12
        1,         ... Torso lower              #13
    });
config.mpii_scale_factor = 0.35;

% GPU ID to use for CNN evaluation. -1 to disable GPU
config.gpuID = 2;

%% Intra-frame GM parameters
% max candidate poses to use per frame
config.MAX_POSES = 100;
% poses will be ignored if any of the parts in nms_parts have detection
% boxes overlapping by more than nms_threshold with a higher scoring
% pose
config.nms_thresh = 0.95;
% part IDs to perform NMS on (currently just wrists)
config.nms_parts = [7 15];

%% Eval parameters
% Which thresholds should we use when calculating PCK statistics?
% Cherian et al. use 15:5:40, but some people use different thresholds. For
% example, Pfister et al. use 0:X:20, where X is a really small step. I think
% I'll ultimately extend the below to 0:5:40. Perhaps 0:2.5:40? The only
% challenge is getting others' results; getting Anoop's results are easy, but I
% also want to compare to Pfister et al., Yang & Ramanan, etc. Pfister doesn't
% seem to have published detections *or* code for PIW (although detections for
% BBC pose are available), which complicates matters. I guess that all I can do
% is shoot an email off to someone on the authors list :/
config.eval_pix_thresholds = 0:2.5:40;

%% If using another dataset, you might need to get the respective pose parameters 
% and set it appropriately in this function.
config.GetDistanceWeightsFn = @Get_Distance_Weights; % a function that returns 
% the weights to be used for each regularization (check practical extension
% in the paper)
config.ComputePartPathCostsFn = @Compute_SkelFlow; % a function that returns 
% the costs from practical extensions.

config.numpts_along_limb = 3; % number of extra keypoints per limb--see practical extensions
config.num_path_parts = 1; % number of sequence paths to compute per body part.

% recombination tree structure. This will change depending on the skeleton
% used in the Y&R algorithm.
config.pose_joints =  get_recombination_tree();
end
