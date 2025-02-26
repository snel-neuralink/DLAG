% =========
% DLAG DEMO 
% ========= 
%
% This demo shows how we can extract latent variables from multi-population
% data with DLAG (Gokcen et al., 2021). It's recommended to run this script
% section-by-section, rather than all at once (or put a break point before
% Sections 2 and 3, as they may take a long time, depending on your use
% of parallelization).
%
% Section 1 demonstrates how DLAG can be used for exploratory data 
% analysis.
%
%     Section 1a fits a DLAG model with a specified number of within-
%     and across-group latent dimensions. Optional arguments are
%     explicitly specified for the sake of demonstration.
%
%     Section 1b takes this model and explores the latent GP timescales and
%     delays. It performs basic inference of within- and across-group 
%     latent trajectories. One can compare estimated parameters and
%     trajectories to the ground truth that underlies the demo synthetic
%     data.
%
%     Section 1c demonstrates how to visually scale and order latents
%     according to various metrics, like variance explained within a group
%     or across-group correlation.
%
%     Section 1d demonstrates how to project latents onto ordered sets of
%     modes that capture shared variance explained within a group or
%     correlation across groups.
%
%     Section 1e demonstrates how to denoise observations using a DLAG
%     model. One can compare raw observations to their denoised
%     counterparts.
%
% Section 2 shows how to select optimal DLAG dimensionalities using 
% a streamlined cross-validation approach. 
%
%     Section 2a estimates the total dimensionality of each group 
%     (within + across) by applying FA to each group independently.
%     See example_fa.m for a detailed demo of FA on multi-population data.
%
%     Section 2b determines the optimal DLAG across- and within-group 
%     dimensionalities using a streamlined cross-validation approach. 
%     The search space is constrained to models such that the across-
%     and within-group dimensionalities for each group add up to the
%     totals established by FA in Section 2b.
%
%     Section 2c fully trains the optimal model selected in Section 2b,
%     assuming the number of EM iterations was limited during
%     cross-validation.
%
% Section 3 demonstrates post-selection inference procedures.
% After selecting the optimal model via cross-validation, these procedures
% can elucidate the uncertainty in parameter estimates.
%
%     Section 3a evaluates how significantly each across-group set of 
%     delays deviates from 0, using bootstrapped samples.
%
%     Section 3b constructs bootstrapped confidence intervals for latent
%     delays and timescales. This section involves re-fitting DLAG models
%     to bootstrapped samples, so its runtime is similar to that of 
%     Section 2, depending on how much parallelization is used.
%
% Author: 
%     Evren Gokcen    egokcen@cmu.edu
%
% Last Revised: 
%     26 Feb 2022

%% ================
% 0a) Load demo data 
% ===================

% Synthetic data generated from a DLAG model
dat_file = 'mat_sample/dlag_demo_data_synthetic';
fprintf('Reading from %s \n',dat_file);
load(dat_file);

%% =======================
% 0b) Set up parallelization
% ===========================

% If parallelize is true, all cross-validation folds and bootstrap samples
% will be analyzed in parallel using Matlab's parfor construct. 
% If you have access to multiple cores, this provides significant speedup.
parallelize = false;
numWorkers = 2;      % Adjust this to your computer's specs

%% =====================
% 1a) Fitting a DLAG model
% ========================

% Let's explicitly define all of the optional arguments, for 
% the sake of demonstration:
runIdx = 1;               % Results will be saved in baseDir/mat_results/runXXX/,  
                          % where XXX is runIdx. Use a new runIdx for each dataset.
baseDir = '.';            % Base directory where results will be saved
overwriteExisting = true; % Control whether existing results files are overwritten
saveData = false;         % Set to true to save train and test data (not recommended)
method = 'dlag';          % For now this is the only option, but that may change in the near future
binWidth = 20;            % Sample period / spike count bin width, in units of time (e.g., ms)
numFolds = 0;             % Number of cross-validation folds (0 means no cross-validation)
xDims_across = 0;         % This number of across-group latents matches the synthetic ground truth
xDims_within = {6, 6};    % These numbers match the within-group latents in the synthetic ground truth
yDims = [10 10];          % Number of observed features (neurons) in each group (area)
rGroups = [1 2];          % For performance evaluation, we can regress group 2's activity with group 1
startTau = 2*binWidth;    % Initial timescale, in the same units of time as binWidth
segLength = 25;           % Largest trial segment length, in no. of time points
init_method = 'static';   % Initialize DLAG with fitted pCCA parameters
learnDelays = true;       % Set to false if you want to fix delays at their initial value
maxIters = 5e3;           % Limit the number of EM iterations (not recommended for final fitting stage)
freqLL = 10;              % Check for data log-likelihood convergence every freqLL EM iterations
freqParam = 100;          % Store intermediate delay and timescale estimates every freqParam EM iterations
minVarFrac = 0.01;        % Private noise variances will not be allowed to go below this value
verbose = true;           % Toggle printed progress updates
randomSeed = 0;           % Seed the random number generator, for reproducibility

fit_dlag(runIdx, seqTrue, ...
         'baseDir', baseDir, ...
         'method', method, ...
         'binWidth', binWidth, ...
         'numFolds', numFolds, ...
         'xDims_across', xDims_across, ...
         'xDims_within', xDims_within, ...
         'yDims', yDims, ...
         'rGroups', rGroups,...
         'startTau', startTau, ...
         'segLength', segLength, ...
         'init_method', init_method, ...
         'learnDelays', learnDelays, ...
         'maxIters', maxIters, ...
         'freqLL', freqLL, ...
         'freqParam', freqParam, ...
         'minVarFrac', minVarFrac, ...
         'parallelize', false, ... % Only relevant for cross-validation
         'verbose', verbose, ...
         'randomSeed', randomSeed, ...
         'overwriteExisting', overwriteExisting, ...
         'saveData', saveData);

%% =========================================================
% 1b) Explore estimated GP parameters and compare to ground truth
% ================================================================

% Retrieve the fitted model of interest
xDim_across = 4;
xDim_within = [2 2];
res = getModel_dlag(runIdx, xDim_across, xDim_within, ...
                    'baseDir', baseDir);

% Plot training progress of various quantities. These plots can help with
% troubleshooting, if necessary.
plotFittingProgress(res, ...
                    'freqLL', freqLL, ...
                    'freqParam', freqParam, ...
                    'units', 'ms');

% Plot estimated within-group GP timescales
plotGPparams_dlag(res.estParams, res.binWidth, res.rGroups, ...
                  'plotAcross', false, ...
                  'plotWithin', true, ...
                  'units', 'ms');
              
% Plot ground truth within-group GP timescales. 
% Note that latent variables are not, in general, ordered. So don't try to
% match estimated latent 1 to ground truth latent 1, and so on.
plotGPparams_dlag(trueParams, res.binWidth, res.rGroups, ...
                  'plotAcross', false, ...
                  'plotWithin', true, ...
                  'units', 'ms');

% Plot estimated and ground truth delays and across-group GP timescales
% together on the same plot. For these scatterplots, it's more
% straightforward to match ground truth latents to corresponding
% estimates.
plotGPparams_withGT_dlag(res.estParams, trueParams, res.binWidth,...
                         res.rGroups, 'units', 'ms');

% Plot estimated latents
[seqEst, ~] = exactInferenceWithLL_dlag(seqTrue, res.estParams);
plotDimsVsTime_dlag(seqEst, 'xsm', res.estParams, res.binWidth, ...
                  'nPlotMax', 1, ...
                  'plotSingle', true, ...
                  'plotMean', true, ...
                  'units', []);

% Plot ground truth latents, in the same format as above.
% Note that latent variables are not, in general, ordered. So don't try to
% match estimated latent 1 to ground truth latent 1, and so on.
plotDimsVsTime_dlag(seqTrue, 'xsm', trueParams, res.binWidth, ...
                  'nPlotMax', 1, ...
                  'plotSingle', true, ...
                  'plotMean', true, ...
                  'units', []);
              
%% ====================================================
% 1c) Visually scale latent trajectories by various metrics
% ==========================================================

% Scale by variance explained
total = false; % true: denominator is total variance; else shared variance
[varexp, ~] = computeVarExp_dlag(res.estParams, total);
[seqEst, sortParams] = scaleByVarExp(seqEst, ...
                                     res.estParams, ...
                                     varexp.indiv, ...
                                     'sortDims', true);
plotDimsVsTime_dlag(seqEst, 'xve', sortParams, res.binWidth, ...
                  'nPlotMax', 20, ...
                  'plotSingle', true, ...
                  'plotMean', false, ...
                  'units', []);
              
% Scale across-area latents by zero-delay correlation
popcorr = computePopCorr_dlag(res.estParams);
[seqEst, sortParams] = scaleByCorr(seqEst, ...
                                   res.estParams, ...
                                   popcorr.lcorr, ...
                                   rGroups, ...
                                   'sortDims', true);
plotDimsVsTime_dlag(seqEst, 'xce', sortParams, res.binWidth, ...
                  'nPlotMax', 20, ...
                  'plotSingle', true, ...
                  'plotMean', false, ...
                  'units', []);
              
% Scale across-area latents by zero-delay covariance
popcov = computePopCov_dlag(res.estParams);
[seqEst, sortParams] = scaleByCorr(seqEst, ...
                                   res.estParams, ...
                                   popcov.lcov, ...
                                   rGroups, ...
                                   'sortDims', true);
plotDimsVsTime_dlag(seqEst, 'xce', sortParams, res.binWidth, ...
                  'nPlotMax', 20, ...
                  'plotSingle', true, ...
                  'plotMean', false, ...
                  'units', []);

%% ============================================
% 1d) Project latents onto different types of modes
% ==================================================  

% Project latents onto dominant modes
seqEst = dominantProjection_dlag(seqEst, res.estParams, ...
                                 'includeAcross', true, ...
                                 'includeWithin', true);
plotDimsVsTime(seqEst, 'xdom', res.binWidth, ...
               'nPlotMax', 20, ...
               'nCol', xDim_across + max(xDim_within), ...
               'plotSingle', true, ...
               'plotMean', false, ...
               'units', 'ms');
           
% Project latents onto zero-delay correlative modes
seqEst = correlativeProjection_dlag(seqEst, res.estParams,...
                                    'orth', false);
plotDimsVsTime(seqEst, 'xcorr', res.binWidth, ...
               'nPlotMax', 20, ...
               'nCol', xDim_across, ...
               'plotSingle', true, ...
               'plotMean', false, ...
               'units', 'ms'); 

% Project latents onto zero-delay predictive modes
seqEst = predictiveProjection_dlag(seqEst,res.estParams, ...
                                   'orth', false, ...
                                   'groupIdxs', rGroups);
% Note that the order of rows corrsponds to the order of rGroups, where
% rGroups(1) is the source group, and rGroups(2) is the target group.
plotDimsVsTime(seqEst, 'xpred', res.binWidth, ...
               'nPlotMax', 20, ...
               'nCol', xDim_across, ...
               'plotSingle', true, ...
               'plotMean', false, ...
               'units', 'ms');
           
% Project latents onto zero-delay covariant modes
seqEst = covariantProjection_dlag(seqEst, res.estParams);
plotDimsVsTime(seqEst, 'xcov', res.binWidth, ...
               'nPlotMax', 20, ...
               'nCol', xDim_across, ...
               'plotSingle', true, ...
               'plotMean', false, ...
               'units', 'ms'); 
              
% Visualize the top three modes in 3D space
xspec = 'xdom';  % Set to any of the mode types above
plotTraj(seqEst, xspec, ...
         'dimsToPlot', 1:3, ...
         'nPlotMax', 1, ...
         'plotSingle', true, ...
         'plotMean', true);     
     
% Related to dominant/covariant modes, inspect the spectra of DLAG loading 
% matrices. These give the amount of shared variance / cross-covariance 
% explained by each mode.
cutoffPC = 0.95;
d_shared = findSharedDimCutoff_dlag(res.estParams, cutoffPC, 'plotSpec', true)

%% =======================================
% 1e) Denoise observations using a DLAG model
% ============================================

% Denoise observations
[seqEst, ~, ~, ~, ~, ~] = denoise_dlag(seqEst, res.estParams);

% Compare PSTHs of raw observations to PSTHs of denoised observations
psth_raw = get_psth(seqEst, 'spec', 'y');
spec = sprintf('yDenoisedOrth%02d', sum(xDim_across + xDim_within));
psth_denoised = get_psth(seqEst, 'spec', spec);

% Raster plots
plotSeqRaster(psth_raw, res.binWidth, 'units', 'ms');
plotSeqRaster(psth_denoised, res.binWidth, 'units', 'ms');

% Heat maps
figure;
hold on;
imagesc(flipud(psth_raw));
colormap('pink');
colorbar;
axis square;
xlabel('Time (ms)');
ylabel('Neurons');
title(sprintf('PSTHs, raw'));

figure;
hold on;
imagesc(flipud(psth_denoised));
colormap('pink');
colorbar;
axis square;
xlabel('Time (ms)');
ylabel('Neurons');
title(sprintf('PSTHs, denoised'));
                                        
%% ===========================================================
% 2a) Cross-validate FA models to estimate total dimensionality 
%     (across+within) in each group.
%  =================================================================

% Change other input arguments as appropriate
runIdx = 2;
numFolds = 4;
xDims = {0:yDims(1)-1, 0:yDims(2)-1}; % Sweep over these dimensionalities

fit_fa(runIdx, seqTrue, ...
       'baseDir', baseDir, ...
       'binWidth', binWidth, ...
       'numFolds', numFolds, ...
       'xDims', xDims, ...
       'yDims', yDims, ...
       'parallelize', parallelize, ...
       'randomSeed', randomSeed, ...
       'numWorkers', numWorkers, ...
       'overwriteExisting', overwriteExisting, ...
       'saveData', saveData);

%% Inspect full cross-validation results
[cvResults, bestModels] = getCrossValResults_fa(runIdx, 'baseDir', baseDir);

% Plot cross-validated performance vs estimated dimensionality
plotPerfvsDim_fa(cvResults, ...
                 'bestModels', bestModels);
               
% Collect the optimal total dimensionality for each group.
numGroups = length(yDims);
xDim_total_fa = nan(1,numGroups);
for groupIdx = 1:numGroups
    xDim_total_fa(groupIdx) = cvResults{groupIdx}(bestModels(groupIdx)).xDim;
end

%% ================================================================
% 2b) Cross-validate DLAG models whose within- and across-group
%     dimensionalities are constrained to sum to the FA estimates.
%  ======================================================================

% Change other input arguments as appropriate
runIdx = 2;
numFolds = 4;
maxIters = 100; % Limit EM iterations during cross-validation for speedup
fitAll = false; % Don't fit a model to all train data
% Determine DLAG models that satisfy the FA constraints
xDims_grid = construct_xDimsGrid(xDim_total_fa);
fit_dlag(runIdx, seqTrue, ...
         'baseDir', baseDir, ...
         'method', method, ...
         'binWidth', binWidth, ...
         'numFolds', numFolds, ...
         'fitAll', fitAll, ...
         'xDims_grid', xDims_grid, ...
         'yDims', yDims, ...
         'rGroups', rGroups,...
         'startTau', startTau, ...
         'segLength', segLength, ...
         'init_method', init_method, ...
         'learnDelays', learnDelays, ...
         'maxIters', maxIters, ...
         'freqLL', freqLL, ...
         'freqParam', freqParam, ...
         'minVarFrac', minVarFrac, ...
         'parallelize', parallelize, ...
         'randomSeed', randomSeed, ...
         'numWorkers', numWorkers, ...
         'overwriteExisting', overwriteExisting, ...
         'saveData', saveData);
     
%% Inspect cross-validation results
% Retrieve cross-validated results for all models in the results directory
[cvResults, ~] = getCrossValResults_dlag(runIdx, 'baseDir', baseDir);

% Plot a variety of performance metrics among the candidate models.
plotPerfvsDim_dlag(cvResults, 'xDims_grid', xDims_grid);

% Select the model with the optimal number among candidates
bestModel = getNumAcrossDim_dlag(cvResults, xDims_grid);

%% ===============================================================
% 2d) Fully train the optimal model selected in Section 2c, assuming EM 
%     iterations were limited during cross-validation.
% ======================================================================

% Change input arguments as appropriate
numFolds = 0;
xDims_across = bestModel.xDim_across;
xDims_within = num2cell(bestModel.xDim_within);
maxIters = 5e3;       % Set to even higher, if desired.

fit_dlag(runIdx, seqTrue, ...
         'baseDir', baseDir, ...
         'method', method, ...
         'binWidth', binWidth, ...
         'numFolds', numFolds, ...
         'xDims_across', xDims_across, ...
         'xDims_within', xDims_within, ...
         'yDims', yDims, ...
         'rGroups', rGroups,...
         'startTau', startTau, ...
         'segLength', segLength, ...
         'init_method', init_method, ...
         'learnDelays', learnDelays, ...
         'maxIters', maxIters, ...
         'freqLL', freqLL, ...
         'freqParam', freqParam, ...
         'minVarFrac', minVarFrac, ...
         'parallelize', false, ... % Only relevant for cross-validation
         'verbose', verbose, ...
         'randomSeed', randomSeed, ...
         'overwriteExisting', overwriteExisting, ...
         'saveData', saveData);                

%% ==========================================================
% 3a) Evaluate how significantly each set of across-group delays
%     deviates from zero.
%  ================================================================

% Retrieve the best DLAG model
xDim_across = bestModel.xDim_across;
xDim_within = bestModel.xDim_within;
res = getModel_dlag(runIdx, xDim_across, xDim_within, 'baseDir', baseDir);

% Save all bootstrap results to a file
boot_fname = generate_inference_fname_dlag(runIdx, ...
                                           'bootstrapResults', ...
                                           xDim_across, ...
                                           xDim_within, ...
                                           'baseDir',baseDir);
numBootstrap = 100; % Number of bootstrap samples (the more the better)
delaySig = bootstrapDelaySignificance(seqTrue, ...
                                      res.estParams, ...
                                      numBootstrap, ...
                                      'parallelize', parallelize, ...
                                      'numWorkers', numWorkers);
% Label each delay as ambiguous (0) or unambiguous (1)
alpha = 0.05; % Significance level
ambiguousIdxs = find(delaySig >= alpha);
fprintf('Indexes of ambiguous delays: %s\n', num2str(ambiguousIdxs)); 
save(boot_fname, 'delaySig');

% Visualize non-zero and statistically ambiguous delays
plotGPparams_dlag(res.estParams, binWidth, rGroups, ...
                  'plotAcross', true, ...
                  'plotWithin', false, ...
                  'units', 'ms', ...
                  'sig', delaySig, ...
                  'alpha', alpha);

%% ==========================================================
% 3b) Construct bootstrapped confidence intervals for latent delays
%     and timescales.
%  ================================================================

alpha = 0.05; % Construct (1-alpha) confidence intervals
bootParams = bootstrapGPparams(seqTrue, ...
                               res.estParams, ...
                               binWidth, ...
                               numBootstrap, ...
                               'alpha', alpha, ...
                               'parallelize', parallelize, ...
                               'numWorkers', numWorkers, ...
                               'segLength', Inf, ...
                               'tolLL', 1e-4, ...
                               'maxIters', 10);
save(boot_fname, 'bootParams', '-append');
plotBootstrapGPparams_dlag(res.estParams, bootParams, binWidth, rGroups,...
                           'overlayParams', false);