function Step7GraphAll3(sourceDir, destFolder, subplotTitle, maxTime, lowPass, highPass)

    if nargin < 4, maxTime = []; end
    if nargin < 5 || isempty(lowPass), lowPass = 30; end
    if nargin < 6, highPass = []; end

    if ~exist(destFolder, 'dir')
        mkdir(destFolder);
    end

    files = dir(fullfile(sourceDir, '*.mat'));
    if isempty(files)
        error('No .mat files found in source directory: %s', sourceDir);
    end

    Fs = 500; nyq = Fs/2;

    % Design filter (same rules as your original)
    if ~isempty(highPass) && ~isempty(lowPass)
        assert(highPass > 0 && lowPass < nyq && highPass < lowPass, ...
            'Require 0 < highPass < lowPass < Fs/2.');
        [b,a] = butter(4, [highPass, lowPass]/nyq, 'bandpass');
    elseif ~isempty(lowPass)
        assert(lowPass > 0 && lowPass < nyq, 'Require 0 < lowPass < Fs/2.');
        [b,a] = butter(4, lowPass/nyq, 'low');
    elseif ~isempty(highPass)
        assert(highPass > 0 && highPass < nyq, 'Require 0 < highPass < Fs/2.');
        [b,a] = butter(4, highPass/nyq, 'high');
    else
        b = 1; a = 1; % no filtering
    end

    for f = 1:numel(files)
        filePath = fullfile(sourceDir, files(f).name);
        disp(['Processing: ', files(f).name]);

        S = load(filePath);
        topNames = fieldnames(S);
        if isempty(topNames)
            warning('Empty MAT: %s', files(f).name); continue;
        end

        root = S.(topNames{1});

        % Support both cases:
        %  - root has field "all_subjects"
        %  - root *is already* the all_subjects struct
        if isstruct(root) && isfield(root, 'all_subjects')
            all_subjects = root.all_subjects;
        else
            all_subjects = root;
        end

        condList = sort(fieldnames(all_subjects));
        if isempty(condList)
            warning('No conditions under all_subjects in %s', files(f).name);
            continue;
        end

        % Infer T from first condition safely
        firstCond = all_subjects.(condList{1});
        if ~isfield(firstCond, 'epoch_avg')
            warning('Missing epoch_avg in first condition of %s', files(f).name);
            continue;
        end
        [~, nT] = size(firstCond.epoch_avg);

        % Time axis (-0.1 to 2.0 s like original)
        tsFull = linspace(-0.1, 2.0, nT);

        % Determine trimming index based on maxTime (seconds)
        if ~isempty(maxTime)
            lastIndex = find(tsFull <= maxTime, 1, 'last');
            if isempty(lastIndex), lastIndex = nT; end
        else
            lastIndex = nT;
            maxTime   = tsFull(end); % for xlim
        end
        ts = tsFull(1:lastIndex);

        % Layout
        numConds = numel(condList);
        subplotCols = 2;
        subplotRows = ceil(numConds / subplotCols);

        fig = figure('Visible', 'off', 'Name', files(f).name, 'NumberTitle', 'off', ...
                     'Position', [100, 100, 1400, 900]);

        for i = 1:numConds
            condition = condList{i};
            condStruct = all_subjects.(condition);

            if ~isfield(condStruct, 'epoch_avg')
                warning('Condition %s missing epoch_avg in %s — skipping.', condition, files(f).name);
                continue;
            end

            % Trim to maxTime and convert to µV
            data = condStruct.epoch_avg(:, 1:lastIndex) * 1e6;
            [rows, ~] = size(data);

            % Per-channel filtering (if enabled)
            for ch = 1:rows
                if all(isfinite(data(ch, :)))
                    data(ch, :) = filtfilt(b, a, data(ch, :));
                else
                    warning('Non-finite values in channel %d (%s); skipping filter.', ch, condition);
                end
            end

            % GFP across channels
            GFP = std(data, 0, 1);

            % Plot
            subplot(subplotRows, subplotCols, i);
            hold on;
            plot(ts, data, 'b', 'LineWidth', 0.5); % channels
            plot(ts, GFP,  'r', 'LineWidth', 2);   % GFP
            xlabel('Time (s)');
            ylabel('Amplitude (\muV)');
            title(condition, 'Interpreter','none');
            grid on;
            xlim([-0.1, maxTime]);
            ylim([-2, 2]);  % keep same y-range
        end

        if numConds > 1
            titleAll = [subplotTitle, ' Average Potentials - ', files(f).name];
            sgtitle(titleAll, 'Interpreter', 'none', 'FontSize', 10);
        end

        % Save (unique filename if exists)
        [~, baseName, ~] = fileparts(files(f).name);
        saveBase = fullfile(destFolder, [baseName, '_AllConditions.png']);
        savePath = saveBase;
        suffix = 1;
        while isfile(savePath)
            savePath = fullfile(destFolder, [baseName, '_AllConditions_', num2str(suffix), '.png']);
            suffix = suffix + 1;
        end

        exportgraphics(fig, savePath);
        close(fig);
        disp(['Saved figure to: ', savePath]);
    end

    disp('All figures processed.');
end
