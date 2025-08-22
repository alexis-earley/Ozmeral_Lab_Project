function Step7GraphGFP_6C2Overlay(inputDir, outputDir, maxTime)

    if nargin < 3 || isempty(maxTime)
        maxTime = []; % keep full length if not provided
    end

    doFilter = 1;
    cutoff = 30;

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    files = dir(fullfile(inputDir, '*.mat'));
    if isempty(files)
        error(['No .mat files found in ', inputDir]);
    end

    fs = 500;        % sampling rate used in your pipeline
    tMin = -0.1;     % start at -100 ms (matches 1051 samples for ~2.1s at 500 Hz)

    % Pre-build LPF if needed
    if doFilter
        [b, a] = butter(4, cutoff / (fs / 2), 'low');
    end

    for f = 1:length(files)
        inPath = fullfile(inputDir, files(f).name);
        data = load(inPath);
        rootNames = fieldnames(data);
        if isempty(rootNames), warning(['Empty file: ', inPath]); continue; end
        root = rootNames{1};           % Ex. Subject_XXXX_6C2
        subjStruct = data.(root);

        % Build list of (blockLabel, condition) and store needed pieces per condition
        allFields = fieldnames(subjStruct);
        % cond -> struct with:
        %   blocks  : cellstr of block labels
        %   gfps    : cell of unweighted GFP traces (1xN, microvolts)
        %   epochs  : cell of epoch_avg matrices (63xN, volts)
        %   weights : cell of num_files vectors (63x1)
        condMap = containers.Map();
        sampleLen = [];  % set from first epoch_avg

        for i = 1:length(allFields)
            field = allFields{i};      % Ex. Block1_2_Attend60R  (or any name with last "_" separating cond)
            % Parse "<anything>_<cond>" by last underscore:
            idx = find(field == '_', 1, 'last');
            if isempty(idx) || idx == length(field)
                continue;  % no underscore or trailing underscore → skip
            end
            blockLabel = field(1:idx-1);   % everything before last "_"
            cond       = field(idx+1:end); % everything after last "_"

            entry = subjStruct.(field);
            if ~isfield(entry, 'epoch_avg'), continue; end
            epoch_avg = entry.epoch_avg;   % 63 x N (volts)

            if isempty(sampleLen)
                sampleLen = size(epoch_avg, 2);
            end

            % Unweighted GFP (μV)
            gfp = std(epoch_avg, 0, 1) * 1e6;

            % Filter if requested
            if doFilter
                gfp = filtfilt(b, a, gfp);
            end

            % Grab weights if present (63x1). If missing, treat as ones.
            if isfield(entry, 'num_files') && ~isempty(entry.num_files)
                w = double(entry.num_files(:));
            else
                w = ones(size(epoch_avg,1), 1);
            end

            % Store
            if ~isKey(condMap, cond)
                s.blocks  = {blockLabel};
                s.gfps    = {gfp};
                s.epochs  = {epoch_avg};
                s.weights = {w};
                condMap(cond) = s;
            else
                s = condMap(cond);
                s.blocks{end+1}  = blockLabel;
                s.gfps{end+1}    = gfp;
                s.epochs{end+1}  = epoch_avg;
                s.weights{end+1} = w;
                condMap(cond) = s;
            end
        end

        if isempty(sampleLen)
            warning(['No epoch_avg found in file: ', inPath]);
            continue;
        end

        % Build common time vector and trim to maxTime if provided
        timeVec = linspace(tMin, tMin + (sampleLen - 1) / fs, sampleLen); % s
        if ~isempty(maxTime)
            lastIndex = find(timeVec <= maxTime * 1000, 1, 'last');
            if isempty(lastIndex), lastIndex = length(timeVec); end
        else
            lastIndex = length(timeVec);
        end
        ts = timeVec(1:lastIndex);

        % Subject label from filename (keep your style)
        [~, baseName, ~] = fileparts(files(f).name);
        subjID = erase(baseName, '_6C2'); % Ex. 'Subject_XXXX'

        % One figure per subject; subplots per condition
        condKeys = condMap.keys;
        nConds = numel(condKeys);
        if nConds == 0
            warning(['No conditions found in file: ', inPath]);
            continue;
        end

        % Grid: square-ish layout
        nCols = ceil(sqrt(nConds));
        nRows = ceil(nConds / nCols);

        figH = figure('Visible', 'off', 'Position', [100, 100, 1400, 900]);
        tl = tiledlayout(figH, nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');

        for k = 1:nConds
            cond = condKeys{k};
            s = condMap(cond);

            nexttile;
            hold on;

            % Plot all block GFPs (unweighted)
            lineHandles = gobjects(0);
            for bIdx = 1:length(s.gfps)
                gfp = s.gfps{bIdx}(1:lastIndex);
                h = plot(ts, gfp, 'LineWidth', 1); % auto color per block
                h.DisplayName = s.blocks{bIdx};
                lineHandles(end+1) = h; %#ok<AGROW>
            end

            % ---- NEW: overall weighted average across blocks (channel-wise) ----
            % Compute weighted epoch average across blocks: for each channel,
            % sum_b w_b(i) * X_b(i,t) / sum_b w_b(i). Then GFP over channels.
            [epochW, ok] = computeWeightedEpochAcrossBlocks(s.epochs, s.weights);
            if ok
                gfpOverall = std(epochW, 0, 1) * 1e6; % μV
                if doFilter
                    gfpOverall = filtfilt(b, a, gfpOverall);
                end
                gfpOverall = gfpOverall(1:lastIndex);
                % Plot as one extra bold line (black, dashed to stand out)
                pOverall = plot(ts, gfpOverall, 'k--', 'LineWidth', 2.2);
                pOverall.DisplayName = 'WeightedAvg (all blocks)';
            end
            % -------------------------------------------------------------------

            % Title, labels, legend
            title(cond, 'Interpreter', 'none', 'FontSize', 10);
            xlim([ts(1), ts(end)]);
            if k > (nRows - 1) * nCols % bottom row
                xlabel('Time (s)');
            end
            if mod(k - 1, nCols) == 0 % first column
                ylabel('GFP (\muV)');
            end

            % Legend; shrink font to avoid overlap
            try
                lgd = legend('Interpreter', 'none', 'Location', 'best');
                set(lgd, 'FontSize', 7);
            catch
                % If legend fails (too many entries), skip quietly
            end
        end

        % Global title and save
        title(tl, [subjID, ' - GFP across Blocks (All Conditions)'], 'Interpreter', 'none', 'FontSize', 12);

        if ~exist(outputDir, 'dir')
            mkdir(outputDir);
        end
        outName = [subjID, '_AllConditions_GFPBlocks.png'];
        saveas(figH, fullfile(outputDir, outName));
        close(figH);

        disp(['Saved figure for subject: ', subjID, ' to ', outputDir]);
    end

    disp('All subject figures saved.');
end

% --- helpers ---

function [epochWeighted, ok] = computeWeightedEpochAcrossBlocks(epochCells, weightCells)
% Weighted average across blocks, channel-wise.
% epochCells : 1xB cell, each 63xN matrix (volts)
% weightCells: 1xB cell, each 63x1 vector (num_files for that block)
% Returns:
%   epochWeighted: 63xN weighted average across blocks (volts)
%   ok           : true if successful, false otherwise

    ok = false;
    if isempty(epochCells) || isempty(weightCells) || numel(epochCells) ~= numel(weightCells)
        epochWeighted = [];
        return;
    end

    % Determine size
    [nCh, nT] = size(epochCells{1});
    sumMat = zeros(nCh, nT);
    sumW   = zeros(nCh, 1);

    for b = 1:numel(epochCells)
        X = epochCells{b};
        w = weightCells{b};
        if isempty(X) || isempty(w), continue; end
        if size(X,1) ~= nCh || size(X,2) ~= nT || numel(w) ~= nCh
            % skip malformed entries
            continue;
        end
        w = double(w(:));
        w(isnan(w)) = 0;

        % Expand weights across time for weighted sum
        sumMat = sumMat + X .* w;     % implicit expansion (63xN .* 63x1)
        sumW   = sumW   + w;
    end

    epochWeighted = zeros(nCh, nT);
    nz = sumW > 0;
    if ~any(nz)
        return; % no weights -> cannot compute
    end
    epochWeighted(nz, :) = sumMat(nz, :) ./ sumW(nz);
    ok = true;
end
