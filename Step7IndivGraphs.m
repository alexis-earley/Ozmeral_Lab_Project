function Step7IndivGraphs(inputDir, outputDir, mvLimit)
% Example:
% Step7IndivGraphsAllSubjects(inputDir, outputDir, 50)

    if ~exist(outputDir, 'dir')
        mkdir(outputDir); % Create main output folder
    end

    % Get all subject files
    subjectFiles = dir(fullfile(inputDir, 'Subject_*.mat'));
    if isempty(subjectFiles)
        error('No subject files found in input directory.');
    end

    for s = 1:length(subjectFiles)
        subjFile = subjectFiles(s).name;
        subjNum = regexp(subjFile, 'Subject_(\d+)', 'tokens', 'once');
        subjNum = subjNum{1};

        % Load subject file
        fullPath = fullfile(inputDir, subjFile);
        fileStruct = load(fullPath);
        varNames = fieldnames(fileStruct);
        subjStruct = fileStruct.(varNames{1});

        condList = fieldnames(subjStruct);

        for c = 1:length(condList)
            condition = condList{c};
            trigList = fieldnames(subjStruct.(condition));

            for t = 1:length(trigList)
                trigger = trigList{t};

                % Get target struct
                dataStruct = subjStruct.(condition).(trigger);
                fileList = fieldnames(dataStruct);
                numFiles = length(fileList);
                ts = linspace(-0.1, 2.0, 1051); % Time in seconds

                fig = figure('Visible', 'off', 'Units', 'pixels', 'Position', [100, 100, 2000, 1200]);
                %fig = figure('Units', 'pixels', 'Position', [100, 100, 2000, 1200]);

                totalPlots = 0;
                for f = 1:numFiles
                    fileName = fileList{f};
                    epochStruct = dataStruct.(fileName);
                    epochNames = fieldnames(epochStruct);
                    totalPlots = totalPlots + length(epochNames);
                end

                plotCount = 0;

                for f = 1:numFiles
                    fileName = fileList{f};
                    epochStruct = dataStruct.(fileName);
                    epochNames = fieldnames(epochStruct);

                    for e = 1:length(epochNames)
                        data = epochStruct.(epochNames{e}) * 1E6; % Convert to µV
                        GFP = std(data);
                        numExceeding = 0;

                        plotCount = plotCount + 1;
                        subplotCols = floor(sqrt(totalPlots));
                        subplotRows = ceil(totalPlots / subplotCols);

                        subplot(subplotRows, subplotCols, plotCount);
                        hold on;

                        % Plot each channel and check if it exceeds threshold
                        for ch = 1:size(data, 1)
                            mvMax = max(abs(data(ch, :)));
                            if mvMax > mvLimit
                                plot(ts, data(ch, :), 'r', 'LineWidth', 1);
                                numExceeding = numExceeding + 1;
                            else
                                plot(ts, data(ch, :), 'k', 'LineWidth', 0.1);
                            end
                        end

                        plot(ts, GFP, 'g', 'LineWidth', 1); % Blue
                        xlabel('Time (s)');
                        ylabel('Amplitude (µV)');
                        xlim([-0.1, 2.0]);

                        % Adjust y-axis
                        if numExceeding > 0
                            ylim('auto'); % Dynamic if any trace exceeded
                        else
                            ylim([-mvLimit, mvLimit]); % Fixed otherwise
                        end

                        % Format title with # exceeding
                        baseTitle = [strrep(fileName, '_', '\_'), ' - ', strrep(epochNames{e}, '_', '\_')];
                        if numExceeding > 0
                            title([baseTitle, ' – ', num2str(numExceeding), ' exceeded']);
                        else
                            title(baseTitle);
                        end
                    end
                end

                % Save figure
                outFolder = fullfile(outputDir, subjNum, condition);
                if ~exist(outFolder, 'dir')
                    mkdir(outFolder);
                end

                graphName = ['Subject ', subjNum, ' - ', condition, ' - ', trigger];
                safeGraphName = strrep(graphName, '_', '\_');
                sgtitle(safeGraphName);

                savePath = fullfile(outFolder, [trigger, '_Subplots.png']);
                exportgraphics(fig, savePath, 'Resolution', 300);
                close(fig);

                disp(['Saved subplot figure to: ', savePath]);
            end
        end
    end
end