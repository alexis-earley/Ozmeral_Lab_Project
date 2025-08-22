function Step7GraphGFP_6C2OverlayInteractive(inputDir, outputDir, maxTime)

    if nargin < 3 || isempty(maxTime), maxTime = []; end

    doFilter = 1;
    cutoff = 30;

    if ~exist(outputDir, 'dir'), mkdir(outputDir); end

    files = dir(fullfile(inputDir, '*.mat'));
    if isempty(files), error(['No .mat files found in ', inputDir]); end

    fs = 500;        % Hz
    tMin = -0.1;     % seconds (−100 ms)

    % LPF for visualization
    if doFilter
        [b, a] = butter(4, cutoff / (fs / 2), 'low');
    end

    for f = 1:numel(files)
        inPath = fullfile(inputDir, files(f).name);
        data = load(inPath);
        rootNames = fieldnames(data);
        if isempty(rootNames), warning(['Empty file: ', inPath]); continue; end
        root = rootNames{1};                % e.g., Subject_XXXX_6C2
        subjStruct = data.(root);

        % Build cond → blocks/gfps/epochs/weights map
        allFields = fieldnames(subjStruct);
        condMap = containers.Map();         % cond -> struct(blocks,gfps,epochs,weights)
        sampleLen = [];

        for i = 1:numel(allFields)
            field = allFields{i};           % e.g., Block1_2_Attend60R
            idx = find(field=='_', 1, 'last');
            if isempty(idx) || idx == length(field), continue; end
            blockLabel = field(1:idx-1);
            cond       = field(idx+1:end);

            entry = subjStruct.(field);
            if ~isfield(entry,'epoch_avg'), continue; end
            epoch_avg = entry.epoch_avg;    % 63 x N (volts)

            if isempty(sampleLen), sampleLen = size(epoch_avg,2); end

            % Unweighted GFP in µV (per block)
            gfp = std(epoch_avg, 0, 1) * 1e6;
            if doFilter, gfp = filtfilt(b, a, gfp); end

            % Weights (63x1), default to ones
            if isfield(entry,'num_files') && ~isempty(entry.num_files)
                w = double(entry.num_files(:));
            else
                w = ones(size(epoch_avg,1),1);
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

        % Time vector (seconds) and optional trim
        timeVec = linspace(tMin, tMin + (sampleLen - 1)/fs, sampleLen); % seconds
        if ~isempty(maxTime)
            lastIndex = find(timeVec <= maxTime, 1, 'last');   % maxTime in SECONDS
            if isempty(lastIndex), lastIndex = numel(timeVec); end
        else
            lastIndex = numel(timeVec);
        end
        ts = timeVec(1:lastIndex);

        % Subject label
        [~, baseName, ~] = fileparts(files(f).name);
        subjID = erase(baseName, '_6C2');

        % Layout: one subplot per condition
        condKeys = condMap.keys;
        nConds   = numel(condKeys);
        if nConds==0, warning(['No conditions in: ', inPath]); continue; end
        nCols = ceil(sqrt(nConds));
        nRows = ceil(nConds / nCols);

        % --- INTERACTIVE FIGURE ---
        figH = figure('Visible','on','Position',[100,100,1400,900], ...
                      'Name', files(f).name, 'NumberTitle', 'off');
        tl = tiledlayout(figH, nRows, nCols, 'TileSpacing','compact','Padding','compact');

        % set up datacursor
        dcm = datacursormode(figH);
        set(dcm,'Enable','on','UpdateFcn',@localGFPTip);

        for k = 1:nConds
            cond = condKeys{k};
            s = condMap(cond);

            ax = nexttile; hold(ax,'on');

            % Plot all block GFPs
            for bIdx = 1:numel(s.gfps)
                gfp = s.gfps{bIdx}(1:lastIndex);
                h = plot(ax, ts, gfp, 'LineWidth', 1);
                h.DisplayName = s.blocks{bIdx};
                h.UserData    = s.blocks{bIdx};   % for tooltip
                h.PickableParts = 'all'; h.HitTest = 'on';
            end

            % Weighted-average GFP across blocks (channel-wise weighted epoch → GFP)
            [epochW, ok] = computeWeightedEpochAcrossBlocks(s.epochs, s.weights);
            if ok
                gfpOverall = std(epochW, 0, 1) * 1e6;
                if doFilter, gfpOverall = filtfilt(b, a, gfpOverall); end
                gfpOverall = gfpOverall(1:lastIndex);

                pOverall = plot(ax, ts, gfpOverall, 'k--', 'LineWidth', 2.2);
                pOverall.DisplayName = 'WeightedAvg (all blocks)';
                pOverall.UserData    = 'WeightedAvg (all blocks)';
                pOverall.PickableParts = 'all'; pOverall.HitTest = 'on';
            end

            title(ax, cond, 'Interpreter','none','FontSize',10);
            xlim(ax, [ts(1), ts(end)]);
            if k > (nRows - 1) * nCols, xlabel(ax,'Time (s)'); end
            if mod(k-1, nCols) == 0,    ylabel(ax,'GFP (\muV)'); end
            grid(ax,'on');

            % Legend
            try
                lgd = legend(ax,'Interpreter','none','Location','best');
                set(lgd,'FontSize',7);
            catch
            end
        end

        title(tl, [subjID, ' - GFP across Blocks (All Conditions)'], ...
              'Interpreter','none','FontSize',12);

        % Save after interaction, then close
        if ~exist(outputDir,'dir'), mkdir(outputDir); end
        outName = [subjID, '_AllConditions_GFPBlocks.png'];
        outFull = fullfile(outputDir, outName);
        exportgraphics(figH, outFull);

        if isgraphics(figH), uiwait(figH); end
        if isgraphics(figH), close(figH); end

        disp(['Saved figure for subject: ', subjID, ' to ', outputDir]);
    end

    disp('All subject figures saved.');
end

% ---------- helpers ----------

function [epochWeighted, ok] = computeWeightedEpochAcrossBlocks(epochCells, weightCells)
% Weighted average across blocks, channel-wise.
% epochCells : 1xB cell, each 63xN matrix (volts)
% weightCells: 1xB cell, each 63x1 vector (num_files for that block)

    ok = false;
    if isempty(epochCells) || isempty(weightCells) || numel(epochCells) ~= numel(weightCells)
        epochWeighted = [];
        return;
    end

    [nCh, nT] = size(epochCells{1});
    sumMat = zeros(nCh, nT);
    sumW   = zeros(nCh, 1);

    for b = 1:numel(epochCells)
        X = epochCells{b};
        w = weightCells{b};
        if isempty(X) || isempty(w), continue; end
        if size(X,1) ~= nCh || size(X,2) ~= nT || numel(w) ~= nCh, continue; end
        w = double(w(:)); w(isnan(w)) = 0;

        sumMat = sumMat + X .* w;   % (63xN .* 63x1)
        sumW   = sumW   + w;
    end

    epochWeighted = zeros(nCh, nT);
    nz = sumW > 0;
    if ~any(nz), return; end
    epochWeighted(nz, :) = sumMat(nz, :) ./ sumW(nz);
    ok = true;
end

function txt = localGFPTip(~, eventObj)
% Datatip callback: shows block label (or 'WeightedAvg'), time, and GFP.
    h = get(eventObj,'Target');
    who = get(h,'UserData');
    p = get(eventObj,'Position');
    if isempty(who), who = 'GFP'; end
    label = strrep(who, '_', '\_');  % escape underscores
    txt = { sprintf('%s', label), ...
            sprintf('Time: %.3f s', p(1)), ...
            sprintf('GFP: %.3f \\muV', p(2)) };

end
