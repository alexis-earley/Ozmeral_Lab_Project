
function Step7CompareGroupsSE(dirList, dirNames, groupPairs, outputDir, maxTime)
    % Create output directory if it doesn't exist
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    Fs = 500;  % Sampling rate in Hz
    totalSamples = 1051;  % Total samples in epoch
    timeVec = linspace(-0.1, 2.1 - 0.1, totalSamples); % Aka -0.1 to 2s
    lastIndex = find(timeVec <= maxTime, 1, 'last');  % Index of last sample <= maxTime
    ts = timeVec(1:lastIndex);  % Trimmed time vector

    % Low-pass filter
    cutoff = 30; % 30 Hz
    [b, a] = butter(4, cutoff / (Fs / 2), 'low');

    allEEG = struct();  % Stores all EEG data organized by condition and group
    allConditions = {};  % Tracks unique condition names

    for g = 1:length(dirList)
        files = dir(fullfile(dirList{g}, '*.mat')); % Get all mat files in group folder
        for f = 1:length(files)
            S = load(fullfile(dirList{g}, files(f).name)); % Load EEG struct
            varName = fieldnames(S);
            subjStruct = S.(varName{1}); % SUbject level
            condNames = fieldnames(subjStruct);
            allConditions = union(allConditions, condNames); % Add condition names list with all

            for c = 1:length(condNames)
                cond = condNames{c};
                eeg = subjStruct.(cond).epoch_avg(:, 1:lastIndex) * 1e6; % Clip to maxTime and convert to microvolts

                for ch = 1:size(eeg, 1)
                    if all(isfinite(eeg(ch, :)))
                        eeg(ch, :) = filtfilt(b, a, eeg(ch, :)); % Low pass filter
                    end
                end

                % Add condition if first time
                if ~isfield(allEEG, cond)
                    allEEG.(cond) = cell(1, length(dirList));
                end
                % Append current EEG data to group’s list for this condition
                allEEG.(cond){g}(end+1, :, :) = eeg;
            end
        end
    end

    % Plot figure per condition
    condList = sort(allConditions); % Alphabetical condition order
    for c = 1:length(condList)
        cond = condList{c};
        fig = figure('Visible', 'off', 'Position', [100, 100, 1600, 900]);

        % For each group pair (e.g., [1 2], [3 4])
        for p = 1:size(groupPairs, 1)
            idx1 = groupPairs(p, 1);
            idx2 = groupPairs(p, 2);
            subplot(2, ceil(size(groupPairs, 1)/2), p); hold on;

            sigMask = false(1, lastIndex);  % Initialize time vector bool as all false

            for gIdx = [idx1, idx2] % Loop over first index in pair and then second one
                EEG = allEEG.(cond){gIdx}; % EEG data

                % Compute GFP per subject (std across channels)
                subjGFPs = squeeze(std(EEG, 0, 2)); % End up with 2D matrix: subjects × time
                GFP = mean(subjGFPs, 1); % Average GFP across subjects - mean(std) method!!
                seGFP = std(subjGFPs, 0, 1) / sqrt(size(EEG, 1)); % Subject SE

                % Plot shaded SE area - recommended method online
                fill([ts fliplr(ts)], [GFP+seGFP fliplr(GFP-seGFP)], ...
                    'k', 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
                % Note to self: [ts fliplr(ts)] = x coords for shaded portion
                % [GFP+seGFP fliplr(GFP-seGFP)] = same for y
                % 'k'= black; 'FaceAlpha', 0.15 = very transparent, 'EdgeColor', 'none' = no border; 
                % 'HandleVisibility', 'off' - don't put in legend

                % Plot GFP
                plot(ts, GFP, 'LineWidth', 2, 'DisplayName', dirNames{gIdx});
            end

            % Run two-sample t-tests between groups at each time point
            gfp1 = squeeze(std(allEEG.(cond){idx1}, 0, 2)); % End up with 2D matrix: subjects × time
            gfp2 = squeeze(std(allEEG.(cond){idx2}, 0, 2)); % Same for other group
            for t = 1:lastIndex
                [h, ~] = ttest2(gfp1(:, t), gfp2(:, t), 'Alpha', 0.05);  % t-test
                sigMask(t) = h;
            end

            % Mark significant timepoints with dots
            %plot(ts(sigMask), -1.8 * ones(1, sum(sigMask)), 'k.', 'MarkerSize', 10);
            plot(ts(sigMask), -0.25 * ones(1, sum(sigMask)), 'k.', 'MarkerSize', 10);

            % Format subplot
            title([cond, ' - ', dirNames{idx1}, ' vs ', dirNames{idx2}]);
            xlabel('Time (s)');
            ylabel('GFP (µV)');
            xlim([-0.1, maxTime]);
            ylim([-0.5, 1.5]);
            grid on;
            legend('Location', 'northwest');
        end

        % Save full plot
        sgtitle(['GFP with SE: ', cond], 'FontSize', 13);
        savePath = fullfile(outputDir, ['CompareGFP_', cond, '.png']);
        exportgraphics(fig, savePath);
        close(fig);
        disp(['Saved: ', savePath]);
    end
end

%{
function Step7CompareGroupsSE(dirList, dirNames, groupPairs, outputDir, maxTime)
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    if nargin < 5 || ~isscalar(maxTime) || maxTime <= 0 || maxTime > 2
        error('maxTime must be a scalar between 0 and 2 seconds.');
    end

    Fs = 500;
    totalSamples = 1051;
    timeVec = linspace(-0.1, 2.1 - 0.1, totalSamples);
    lastIndex = find(timeVec <= maxTime, 1, 'last');
    ts = timeVec(1:lastIndex);
    cutoff = 30;
    [b, a] = butter(4, cutoff / (Fs / 2), 'low');

    allEEG = struct();  
    allConditions = {};

    % Load EEG data from all groups
    for g = 1:length(dirList)
        files = dir(fullfile(dirList{g}, '*.mat'));
        for f = 1:length(files)
            S = load(fullfile(dirList{g}, files(f).name));
            varName = fieldnames(S);
            subjStruct = S.(varName{1});
            condNames = fieldnames(subjStruct);
            allConditions = union(allConditions, condNames);

            for c = 1:length(condNames)
                cond = condNames{c};
                eeg = subjStruct.(cond).epoch_avg(:, 1:lastIndex) * 1e6;

                for ch = 1:size(eeg, 1)
                    if all(isfinite(eeg(ch, :)))
                        eeg(ch, :) = filtfilt(b, a, eeg(ch, :));
                    end
                end

                if ~isfield(allEEG, cond)
                    allEEG.(cond) = cell(1, length(dirList));
                end
                allEEG.(cond){g}(end+1, :, :) = eeg;
            end
        end
    end

    % Generate figure per condition
    condList = sort(allConditions);
    for c = 1:length(condList)
        cond = condList{c};
        fig = figure('Visible', 'off', 'Position', [100, 100, 1600, 900]);

        for p = 1:size(groupPairs, 1)
            idx1 = groupPairs(p, 1);
            idx2 = groupPairs(p, 2);
            subplot(2, ceil(size(groupPairs, 1)/2), p); hold on;

            sigMask = false(1, lastIndex);

            for gIdx = [idx1, idx2] % Ex. gIdx = 1 then gIdx = 4
                EEG = allEEG.(cond){gIdx};
                %subjAvg = squeeze(mean(EEG, 1));
                %GFP = std(subjAvg, 0, 1);
                subjGFPs = squeeze(std(EEG, 0, 2));  % NEW
                GFP = mean(subjGFPs, 1); % NEW
                subjGFPs = squeeze(std(EEG, 0, 2));
                seGFP = std(subjGFPs, 0, 1) / sqrt(size(EEG, 1));
                fill([ts fliplr(ts)], [GFP+seGFP fliplr(GFP-seGFP)], ...
                    'k', 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
                plot(ts, GFP, 'LineWidth', 2, 'DisplayName', dirNames{gIdx}); % Changed from 2 - PLOT
            end

            % Run t-tests across time
            gfp1 = squeeze(std(allEEG.(cond){idx1}, 0, 2));  % subj x time
            gfp2 = squeeze(std(allEEG.(cond){idx2}, 0, 2));
            for t = 1:lastIndex
                [h, ~] = ttest2(gfp1(:, t), gfp2(:, t), 'Alpha', 0.07); % CHANGE BACK
                sigMask(t) = h;
            end

            % Mark significance
            plot(ts(sigMask), -1.8 * ones(1, sum(sigMask)), 'k.', 'MarkerSize', 10); % PLOT

            title([cond, ' | ', dirNames{idx1}, ' vs ', dirNames{idx2}]);
            xlabel('Time (s)');
            ylabel('GFP (µV)');
            xlim([-0.1, maxTime]);
            ylim([-2, 2]);
            grid on;
            legend('Location', 'northeast');
        end

        sgtitle(['GFP with SE: ', cond], 'FontSize', 13);
        savePath = fullfile(outputDir, ['CompareGFP_', cond, '.png']);
        exportgraphics(fig, savePath);
        close(fig);
        disp(['Saved: ', savePath]);
    end
end
%}