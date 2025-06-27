clc;
currency_value = input('Enter the currency value: ');
access = input('Enter "c" for camera or enter "i" for input image: ', 's');

if access == 'i'
    inputimage = input('Enter the image name: ', 's');
    capturedImage = imread(inputimage);
    figure;
    imshow(capturedImage);
elseif access == 'c'
    % Open webcam and start live feed
    cam = webcam;  % Create a webcam object
    
    % Set webcam resolution to one of the available options (e.g., '1280x720')
    cam.Resolution = '1280x720';  % Use a supported resolution
    
    % Create a figure window to display the webcam feed
    figure;
    hImage = imshow(snapshot(cam));  % Show the initial frame
    title('Press Enter to Capture the Image');
    axis tight;
    
    % Display a message to guide the user
    disp('Live feed is on. Adjust the camera, and press Enter when ready to capture.');
    
    % Start a loop to display the live video feed
    while true
        % Capture a new image frame
        img = snapshot(cam);
        
        % Update the displayed image
        set(hImage, 'CData', img);
        
        % Pause for a short time to update the display
        pause(0.1);
        
        % Check if the user pressed Enter to capture the image
        key = get(gcf, 'CurrentKey');  % Get the current key pressed
        if strcmp(key, 'return')  % If Enter key is pressed
            % Capture the current frame
            capturedImage = snapshot(cam);  % Capture the frame at the moment Enter is pressed
            
            % Display the captured image
            figure;
            imshow(capturedImage);
            title('Captured Image');
            
            % Exit the loop after capturing the image
            break;
        end
    end
    
    % Release the webcam
    clear cam;
end

% The captured image is now available for further processing
% You can apply any further operations on the capturedImage

if currency_value == 2000
    % Define folders for each feature
    featureFolders = {'feature 1[value]', 'feature 2[rbi seal]', 'feature 3[reserve bank of india]', 'feature 4[latent image]', 'feature 5[italic value]', 'feature 6[hindi 2000]', 'feature 7[rbi hindi]'};
    numFeatures = numel(featureFolders);

    % Convert the captured image to grayscale if necessary
    inputImageGray = im2gray(capturedImage);

    % Initialize result flag
    isGenuine = true;

    % Loop through each feature folder
    for f = 1:numFeatures
        featureFolder = featureFolders{f};
        featureMatched = false;

        % Get list of images in the current feature folder
        featureImages = dir(fullfile(featureFolder, '*.jpg'));

        % Detect features in the input image using SURF
        inputPoints = detectSURFFeatures(inputImageGray);
        [inputFeatures, inputValidPoints] = extractFeatures(inputImageGray, inputPoints);

        % Loop through each image in the feature folder
        for k = 1:numel(featureImages)
            % Load each feature image
            featureImage = imread(fullfile(featureFolder, featureImages(k).name));
            featureImageGray = rgb2gray(featureImage);

            % Detect features in the feature image using SURF
            featurePoints = detectSURFFeatures(featureImageGray);
            [featureFeatures, featureValidPoints] = extractFeatures(featureImageGray, featurePoints);

            % Match features between input image and feature image
            indexPairs = matchFeatures(inputFeatures, featureFeatures);

            % Check if there are enough matches
            if numel(indexPairs) >= 10
                featureMatched = true;

                % If the currency is genuine, display matched features
                if isGenuine
                    matchedInputPoints = inputValidPoints(indexPairs(:, 1));
                    matchedFeaturePoints = featureValidPoints(indexPairs(:, 2));

                    % Show matched features
                    figure('Name', ['Matched Features for ', featureImages(k).name]);
                    showMatchedFeatures(inputImageGray, featureImageGray, matchedInputPoints, matchedFeaturePoints, 'montage');
                    title(['Matched Features for: ', featureImages(k).name]);
                    axis image;
                end
                break;
            end
        end

        % If no match found for this feature, mark as counterfeit and exit loop
        if ~featureMatched
            isGenuine = false;
            fprintf('Feature %d did not match. The currency is counterfeit.\n', f);

            % Display the first unmatched feature image
            unmatchedFeatureImage = imread(fullfile(featureFolder, featureImages(1).name));
            figure('Name', ['Unmatched Feature: ', featureFolders{f}]);
            imshow(unmatchedFeatureImage);
            title(['Unmatched Feature: ', featureFolders{f}]);
            axis image;

            break;
        end
    end

    % If all features matched, proceed to security thread detection
    if isGenuine
        % Convert the image to HSV color space
        capturedImage=imresize(capturedImage, [800 1900]);
        hsvImage = rgb2hsv(capturedImage);

        % Extract the Value (V) channel
        valueChannel = hsvImage(:, :, 3);

        % Get the size of the image
        [height, width, ~] = size(capturedImage);

        % Define the crop size (e.g., 500x900 pixels)
        cropWidth = 175;  % Width of the cropped area
        cropHeight = 450; % Height of the cropped area

        % Calculate the coordinates for cropping around the center
        centerX = round(width / 2);  % X-coordinate of the image center
        centerY = round(height / 2); % Y-coordinate of the image center

        % Calculate the cropping rectangle [x, y, width, height]
        cropRect = [centerX + cropWidth / 2, centerY - cropHeight / 2, cropWidth, cropHeight];

        % Crop the Value channel image to the defined region
        roiImage = imcrop(valueChannel, cropRect);
        figure;imshow(roiImage);
        % Threshold to isolate dark regions (potential security thread) in the ROI
        darkRegionsMask = roiImage < 0.35; % Adjusted for darker regions

        % Perform morphological operations to refine the mask in the ROI
        se = strel('rectangle', [3, 10]); % Adjusted structuring element
        refinedMask = imclose(darkRegionsMask, se); % Close gaps in vertical patterns
        refinedMask = bwareaopen(refinedMask, 100); % Remove small noise regions

        % Label connected components in the refined mask
        labeledRegions = bwconncomp(refinedMask);

        % Visualize all detected regions in the ROI
        figure; imshow(refinedMask); title('Detected Regions in ROI');
        hold on;
        stats = regionprops(labeledRegions, 'BoundingBox');
        for i = 1:length(stats)
            rectangle('Position', stats(i).BoundingBox, 'EdgeColor', 'g', 'LineWidth', 1);
        end
        hold off;

        % Measure properties of connected components
        regionProps = regionprops(labeledRegions, 'BoundingBox', 'Area', 'Centroid');

        % Initialize detection flag
        isBandDetected = false;

        % Process each detected region to find square-shaped bands
        for i = 1:length(regionProps)
            % Get region properties
            bbox = regionProps(i).BoundingBox;
            widthRegion = bbox(3);
            heightRegion = bbox(4);

            % Check for square bands (width and height should be nearly equal)
            if abs(widthRegion - heightRegion) < 10 && widthRegion > 5 && heightRegion > 5
                % Mark the region as a square band
                isBandDetected = true;
                break; % Stop checking once a valid square band is detected
            end
        end

        % Display final decision
        if isBandDetected
            disp('Square-shaped bands detected in the selected ROI. The currency is genuine.');
            % Show the message in a custom figure window
            display_message('The currency is genuine.', isGenuine);
        else
            disp('No square-shaped bands detected in the selected ROI. The currency may be counterfeit.');
            % Show the message in a custom figure window
            display_message('The currency may be counterfeit. No security thread detected', isGenuine);
        end
    else
        disp('Currency is counterfeit. Security thread detection skipped.');
        % Show the message in a custom figure window
        display_message('The currency is counterfeit as features mismatched', isGenuine);
    end


elseif currency_value == 500
    % Define folders for each feature
    featureFolders = {'500 feature 1[value]', '500 feature 2[rbi seal]', '500 feature 3[reserve bank of india]', '500 feature 4[latent image]', '500 feature 5[italic value]', '500 feature 6[hindi 500]', '500 feature 7[rbi hindi]'};
    numFeatures = numel(featureFolders);

    % Convert the captured image to grayscale if necessary
    inputImageGray = im2gray(capturedImage);

    % Initialize result flag
    isGenuine = true;

    % Loop through each feature folder
    for f = 1:numFeatures
        featureFolder = featureFolders{f};
        featureMatched = false;

        % Get list of images in the current feature folder
        featureImages = dir(fullfile(featureFolder, '*.jpg'));

        % Detect features in the input image using SURF
        inputPoints = detectSURFFeatures(inputImageGray);
        [inputFeatures, inputValidPoints] = extractFeatures(inputImageGray, inputPoints);

        % Loop through each image in the feature folder
        for k = 1:numel(featureImages)
            % Load each feature image
            featureImage = imread(fullfile(featureFolder, featureImages(k).name));
            featureImageGray = rgb2gray(featureImage);

            % Detect features in the feature image using SURF
            featurePoints = detectSURFFeatures(featureImageGray);
            [featureFeatures, featureValidPoints] = extractFeatures(featureImageGray, featurePoints);

            % Match features between input image and feature image
            indexPairs = matchFeatures(inputFeatures, featureFeatures);

            % Check if there are enough matches
            if numel(indexPairs) >= 10
                featureMatched = true;

                % If the currency is genuine, display matched features
                if isGenuine
                    matchedInputPoints = inputValidPoints(indexPairs(:, 1));
                    matchedFeaturePoints = featureValidPoints(indexPairs(:, 2));

                    % Show matched features
                    figure('Name', ['Matched Features for ', featureImages(k).name]);
                    showMatchedFeatures(inputImageGray, featureImageGray, matchedInputPoints, matchedFeaturePoints, 'montage');
                    title(['Matched Features for: ', featureImages(k).name]);
                    axis image;
                end
                break;
            end
        end

        % If no match found for this feature, mark as counterfeit and exit loop
        if ~featureMatched
            isGenuine = false;
            fprintf('Feature %d did not match. The currency is counterfeit.\n', f);

            % Display the first unmatched feature image
            unmatchedFeatureImage = imread(fullfile(featureFolder, featureImages(1).name));
            figure('Name', ['Unmatched Feature: ', featureFolders{f}]);
            imshow(unmatchedFeatureImage);
            title(['Unmatched Feature: ', featureFolders{f}]);
            axis image;

            break;
        end
    end

    % If all features matched, proceed to security thread detection
    if isGenuine
        % Convert the image to HSV color space
        capturedImage=imresize(capturedImage, [800 1750]);
        hsvImage = rgb2hsv(capturedImage);

        % Extract the Value (V) channel
        valueChannel = hsvImage(:, :, 3);

        % Get the size of the image
        [height, width, ~] = size(capturedImage);

        % Define the crop size (e.g., 500x900 pixels)
        cropWidth = 170;  % Width of the cropped area
        cropHeight = 450; % Height of the cropped area

        % Calculate the coordinates for cropping around the center
        centerX = round(width / 2);  % X-coordinate of the image center
        centerY = round(height / 2); % Y-coordinate of the image center

        % Calculate the cropping rectangle [x, y, width, height]
        cropRect = [centerX + cropWidth / 2, centerY - cropHeight / 2, cropWidth, cropHeight];

        % Crop the Value channel image to the defined region
        roiImage = imcrop(valueChannel, cropRect);

        % Threshold to isolate dark regions (potential security thread) in the ROI
        darkRegionsMask = roiImage < 0.35; % Adjusted for darker regions

        % Perform morphological operations to refine the mask in the ROI
        se = strel('rectangle', [3, 10]); % Adjusted structuring element
        refinedMask = imclose(darkRegionsMask, se); % Close gaps in vertical patterns
        refinedMask = bwareaopen(refinedMask, 100); % Remove small noise regions

        % Label connected components in the refined mask
        labeledRegions = bwconncomp(refinedMask);

        % Visualize all detected regions in the ROI
        figure; imshow(refinedMask); title('Detected Regions in ROI');
        hold on;
        stats = regionprops(labeledRegions, 'BoundingBox');
        for i = 1:length(stats)
            rectangle('Position', stats(i).BoundingBox, 'EdgeColor', 'g', 'LineWidth', 1);
        end
        hold off;

        % Measure properties of connected components
        regionProps = regionprops(labeledRegions, 'BoundingBox', 'Area', 'Centroid');

        % Initialize detection flag
        isBandDetected = false;

        % Process each detected region to find square-shaped bands
        for i = 1:length(regionProps)
            % Get region properties
            bbox = regionProps(i).BoundingBox;
            widthRegion = bbox(3);
            heightRegion = bbox(4);

            % Check for square bands (width and height should be nearly equal)
            if abs(widthRegion - heightRegion) < 10 && widthRegion > 5 && heightRegion > 5
                % Mark the region as a square band
                isBandDetected = true;
                break; % Stop checking once a valid square band is detected
            end
        end

        % Display final decision
        if isBandDetected
            disp('Square-shaped bands detected in the selected ROI. The currency is genuine.');
            % Show the message in a custom figure window
            display_message('The currency is genuine.', isGenuine);
        else
            disp('No square-shaped bands detected in the selected ROI. The currency may be counterfeit.');
            % Show the message in a custom figure window
            display_message('The currency may be counterfeit.', isGenuine);
        end
    else
        disp('Currency is counterfeit. Security thread detection skipped.');
        % Show the message in a custom figure window
        display_message('The currency is counterfeit.', isGenuine);
    end

elseif currency_value == 200
    % Define folders for each feature
    featureFolders = {'200 feature 1[value]', '200 feature 2[rbi seal]', '200 feature 3[reserve bank of india]', '200 feature 5[italic value]'};
    numFeatures = numel(featureFolders);

    % Convert the captured image to grayscale if necessary
    inputImageGray = im2gray(capturedImage);

    % Initialize result flag
    isGenuine = true;

    % Loop through each feature folder
    for f = 1:numFeatures
        featureFolder = featureFolders{f};
        featureMatched = false;

        % Get list of images in the current feature folder
        featureImages = dir(fullfile(featureFolder, '*.jpg'));

        % Detect features in the input image using SURF
        inputPoints = detectSURFFeatures(inputImageGray);
        [inputFeatures, inputValidPoints] = extractFeatures(inputImageGray, inputPoints);

        % Loop through each image in the feature folder
        for k = 1:numel(featureImages)
            % Load each feature image
            featureImage = imread(fullfile(featureFolder, featureImages(k).name));
            featureImageGray = rgb2gray(featureImage);

            % Detect features in the feature image using SURF
            featurePoints = detectSURFFeatures(featureImageGray);
            [featureFeatures, featureValidPoints] = extractFeatures(featureImageGray, featurePoints);

            % Match features between input image and feature image
            indexPairs = matchFeatures(inputFeatures, featureFeatures);

            % Check if there are enough matches
            if numel(indexPairs) >= 10
                featureMatched = true;

                % If the currency is genuine, display matched features
                if isGenuine
                    matchedInputPoints = inputValidPoints(indexPairs(:, 1));
                    matchedFeaturePoints = featureValidPoints(indexPairs(:, 2));

                    % Show matched features
                    figure('Name', ['Matched Features for ', featureImages(k).name]);
                    showMatchedFeatures(inputImageGray, featureImageGray, matchedInputPoints, matchedFeaturePoints, 'montage');
                    title(['Matched Features for: ', featureImages(k).name]);
                    axis image;
                end
                break;
            end
        end

        % If no match found for this feature, mark as counterfeit and exit loop
        if ~featureMatched
            isGenuine = false;
            fprintf('Feature %d did not match. The currency is counterfeit.\n', f);

            % Display the first unmatched feature image
            unmatchedFeatureImage = imread(fullfile(featureFolder, featureImages(1).name));
            figure('Name', ['Unmatched Feature: ', featureFolders{f}]);
            imshow(unmatchedFeatureImage);
            title(['Unmatched Feature: ', featureFolders{f}]);
            axis image;

            break;
        end
    end

    % If all features matched, proceed to security thread detection
    if isGenuine
        % Convert the image to HSV color space
        capturedImage=imresize(capturedImage, [800,1700]);
        hsvImage = rgb2hsv(capturedImage);

        % Extract the Value (V) channel
        valueChannel = hsvImage(:, :, 3);

        % Get the size of the image
        [height, width, ~] = size(capturedImage);

        % Define the crop size (e.g., 500x900 pixels)
        cropWidth = 170;  % Width of the cropped area
        cropHeight = 450; % Height of the cropped area

        % Calculate the coordinates for cropping around the center
        centerX = round(width / 2);  % X-coordinate of the image center
        centerY = round(height / 2); % Y-coordinate of the image center

        % Calculate the cropping rectangle [x, y, width, height]
        cropRect = [centerX + cropWidth / 2, centerY - cropHeight / 2, cropWidth, cropHeight];

        % Crop the Value channel image to the defined region
        roiImage = imcrop(valueChannel, cropRect);

        % Threshold to isolate dark regions (potential security thread) in the ROI
        darkRegionsMask = roiImage < 0.35; % Adjusted for darker regions

        % Perform morphological operations to refine the mask in the ROI
        se = strel('rectangle', [3, 10]); % Adjusted structuring element
        refinedMask = imclose(darkRegionsMask, se); % Close gaps in vertical patterns
        refinedMask = bwareaopen(refinedMask, 100); % Remove small noise regions

        % Label connected components in the refined mask
        labeledRegions = bwconncomp(refinedMask);

        % Visualize all detected regions in the ROI
        figure; imshow(refinedMask); title('Detected Regions in ROI');
        hold on;
        stats = regionprops(labeledRegions, 'BoundingBox');
        for i = 1:length(stats)
            rectangle('Position', stats(i).BoundingBox, 'EdgeColor', 'g', 'LineWidth', 1);
        end
        hold off;

        % Measure properties of connected components
        regionProps = regionprops(labeledRegions, 'BoundingBox', 'Area', 'Centroid');

        % Initialize detection flag
        isBandDetected = false;

        % Process each detected region to find square-shaped bands
        for i = 1:length(regionProps)
            % Get region properties
            bbox = regionProps(i).BoundingBox;
            widthRegion = bbox(3);
            heightRegion = bbox(4);

            % Check for square bands (width and height should be nearly equal)
            if abs(widthRegion - heightRegion) < 10 && widthRegion > 5 && heightRegion > 5
                % Mark the region as a square band
                isBandDetected = true;
                break; % Stop checking once a valid square band is detected
            end
        end

        % Display final decision
        if isBandDetected
            disp('Square-shaped bands detected in the selected ROI. The currency is genuine.');
            % Show the message in a custom figure window
            display_message('The currency is genuine.', isGenuine);
        else
            disp('No square-shaped bands detected in the selected ROI. The currency may be counterfeit.');
            % Show the message in a custom figure window
            display_message('The currency may be counterfeit.', isGenuine);
        end
    else
        disp('Currency is counterfeit. Security thread detection skipped.');
        % Show the message in a custom figure window
        display_message('The currency is counterfeit.', isGenuine);
    end

elseif currency_value == 100
    % Define folders for each feature
    featureFolders = {'100 feature 1[value]', '100 feature 2[rbi seal]', '100 feature 3[reserve bank of india]', '100 feature 5[italic value]'};
    numFeatures = numel(featureFolders);

    % Convert the captured image to grayscale if necessary
    inputImageGray = im2gray(capturedImage);

    % Initialize result flag
    isGenuine = true;

    % Loop through each feature folder
    for f = 1:numFeatures
        featureFolder = featureFolders{f};
        featureMatched = false;

        % Get list of images in the current feature folder
        featureImages = dir(fullfile(featureFolder, '*.jpg'));

        % Detect features in the input image using SURF
        inputPoints = detectSURFFeatures(inputImageGray);
        [inputFeatures, inputValidPoints] = extractFeatures(inputImageGray, inputPoints);

        % Loop through each image in the feature folder
        for k = 1:numel(featureImages)
            % Load each feature image
            featureImage = imread(fullfile(featureFolder, featureImages(k).name));
            featureImageGray = rgb2gray(featureImage);

            % Detect features in the feature image using SURF
            featurePoints = detectSURFFeatures(featureImageGray);
            [featureFeatures, featureValidPoints] = extractFeatures(featureImageGray, featurePoints);

            % Match features between input image and feature image
            indexPairs = matchFeatures(inputFeatures, featureFeatures);

            % Check if there are enough matches
            if numel(indexPairs) >= 10
                featureMatched = true;

                % If the currency is genuine, display matched features
                if isGenuine
                    matchedInputPoints = inputValidPoints(indexPairs(:, 1));
                    matchedFeaturePoints = featureValidPoints(indexPairs(:, 2));

                    % Show matched features
                    figure('Name', ['Matched Features for ', featureImages(k).name]);
                    showMatchedFeatures(inputImageGray, featureImageGray, matchedInputPoints, matchedFeaturePoints, 'montage');
                    title(['Matched Features for: ', featureImages(k).name]);
                    axis image;
                end
                break;
            end
        end

        % If no match found for this feature, mark as counterfeit and exit loop
        if ~featureMatched
            isGenuine = false;
            fprintf('Feature %d did not match. The currency is counterfeit.\n', f);

            % Display the first unmatched feature image
            unmatchedFeatureImage = imread(fullfile(featureFolder, featureImages(1).name));
            figure('Name', ['Unmatched Feature: ', featureFolders{f}]);
            imshow(unmatchedFeatureImage);
            title(['Unmatched Feature: ', featureFolders{f}]);
            axis image;

            break;
        end
    end

    % If all features matched, proceed to security thread detection
    if isGenuine
        % Convert the image to HSV color space
        capturedImage=imresize(capturedImage, [800 1650]);
        hsvImage = rgb2hsv(capturedImage);

        % Extract the Value (V) channel
        valueChannel = hsvImage(:, :, 3);

        % Get the size of the image
        [height, width, ~] = size(capturedImage);

        % Define the crop size (e.g., 500x900 pixels)
        cropWidth = 170;  % Width of the cropped area
        cropHeight = 450; % Height of the cropped area

        % Calculate the coordinates for cropping around the center
        centerX = round(width / 2);  % X-coordinate of the image center
        centerY = round(height / 2); % Y-coordinate of the image center

        % Calculate the cropping rectangle [x, y, width, height]
        cropRect = [centerX + cropWidth / 2, centerY - cropHeight / 2, cropWidth, cropHeight];

        % Crop the Value channel image to the defined region
        roiImage = imcrop(valueChannel, cropRect);

        % Threshold to isolate dark regions (potential security thread) in the ROI
        darkRegionsMask = roiImage < 0.35; % Adjusted for darker regions

        % Perform morphological operations to refine the mask in the ROI
        se = strel('rectangle', [3, 10]); % Adjusted structuring element
        refinedMask = imclose(darkRegionsMask, se); % Close gaps in vertical patterns
        refinedMask = bwareaopen(refinedMask, 100); % Remove small noise regions

        % Label connected components in the refined mask
        labeledRegions = bwconncomp(refinedMask);

        % Visualize all detected regions in the ROI
        figure; imshow(refinedMask); title('Detected Regions in ROI');
        hold on;
        stats = regionprops(labeledRegions, 'BoundingBox');
        for i = 1:length(stats)
            rectangle('Position', stats(i).BoundingBox, 'EdgeColor', 'g', 'LineWidth', 1);
        end
        hold off;

        % Measure properties of connected components
        regionProps = regionprops(labeledRegions, 'BoundingBox', 'Area', 'Centroid');

        % Initialize detection flag
        isBandDetected = false;

        % Process each detected region to find square-shaped bands
        for i = 1:length(regionProps)
            % Get region properties
            bbox = regionProps(i).BoundingBox;
            widthRegion = bbox(3);
            heightRegion = bbox(4);

            % Check for square bands (width and height should be nearly equal)
            if abs(widthRegion - heightRegion) < 10 && widthRegion > 5 && heightRegion > 5
                % Mark the region as a square band
                isBandDetected = true;
                break; % Stop checking once a valid square band is detected
            end
        end

        % Display final decision
        if isBandDetected
            disp('Square-shaped bands detected in the selected ROI. The currency is genuine.');
            % Show the message in a custom figure window
            display_message('The currency is genuine.', isGenuine);
        else
            disp('No square-shaped bands detected in the selected ROI. The currency may be counterfeit.');
            % Show the message in a custom figure window
            display_message('The currency may be counterfeit.', isGenuine);
        end
    else
        disp('Currency is counterfeit. Security thread detection skipped.');
        % Show the message in a custom figure window
        display_message('The currency is counterfeit.', isGenuine);
    end

elseif currency_value == 50
    % Define folders for each feature
    featureFolders = {'50 feature 1[value]', '50 feature 2[rbi seal]', '50 feature 3[reserve bank of india]', '50 feature 5[italic value]'};
    numFeatures = numel(featureFolders);

    % Convert the captured image to grayscale if necessary
    inputImageGray = im2gray(capturedImage);

    % Initialize result flag
    isGenuine = true;

    % Loop through each feature folder
    for f = 1:numFeatures
        featureFolder = featureFolders{f};
        featureMatched = false;

        % Get list of images in the current feature folder
        featureImages = dir(fullfile(featureFolder, '*.jpg'));

        % Detect features in the input image using SURF
        inputPoints = detectSURFFeatures(inputImageGray);
        [inputFeatures, inputValidPoints] = extractFeatures(inputImageGray, inputPoints);

        % Loop through each image in the feature folder
        for k = 1:numel(featureImages)
            % Load each feature image
            featureImage = imread(fullfile(featureFolder, featureImages(k).name));
            featureImageGray = rgb2gray(featureImage);

            % Detect features in the feature image using SURF
            featurePoints = detectSURFFeatures(featureImageGray);
            [featureFeatures, featureValidPoints] = extractFeatures(featureImageGray, featurePoints);

            % Match features between input image and feature image
            indexPairs = matchFeatures(inputFeatures, featureFeatures);

            % Check if there are enough matches
            if numel(indexPairs) >= 10
                featureMatched = true;

                % If the currency is genuine, display matched features
                if isGenuine
                    matchedInputPoints = inputValidPoints(indexPairs(:, 1));
                    matchedFeaturePoints = featureValidPoints(indexPairs(:, 2));

                    % Show matched features
                    figure('Name', ['Matched Features for ', featureImages(k).name]);
                    showMatchedFeatures(inputImageGray, featureImageGray, matchedInputPoints, matchedFeaturePoints, 'montage');
                    title(['Matched Features for: ', featureImages(k).name]);
                    axis image;
                end
                break;
            end
        end

        % If no match found for this feature, mark as counterfeit and exit loop
        if ~featureMatched
            isGenuine = false;
            fprintf('Feature %d did not match. The currency is counterfeit.\n', f);

            % Display the first unmatched feature image
            unmatchedFeatureImage = imread(fullfile(featureFolder, featureImages(1).name));
            figure('Name', ['Unmatched Feature: ', featureFolders{f}]);
            imshow(unmatchedFeatureImage);
            title(['Unmatched Feature: ', featureFolders{f}]);
            axis image;

            break;
        end
    end

    % If all features matched, proceed to security thread detection
    if isGenuine
        % Convert the image to HSV color space
        capturedImage=imresize(capturedImage, [800 1600]);
        hsvImage = rgb2hsv(capturedImage);

        % Extract the Value (V) channel
        valueChannel = hsvImage(:, :, 3);

        % Get the size of the image
        [height, width, ~] = size(capturedImage);

        % Define the crop size (e.g., 500x900 pixels)
        cropWidth = 165;  % Width of the cropped area
        cropHeight = 450; % Height of the cropped area

        % Calculate the coordinates for cropping around the center
        centerX = round(width / 2);  % X-coordinate of the image center
        centerY = round(height / 2); % Y-coordinate of the image center

        % Calculate the cropping rectangle [x, y, width, height]
        cropRect = [centerX + cropWidth / 2, centerY - cropHeight / 2, cropWidth, cropHeight];

        % Crop the Value channel image to the defined region
        roiImage = imcrop(valueChannel, cropRect);

        % Threshold to isolate dark regions (potential security thread) in the ROI
        darkRegionsMask = roiImage < 0.35; % Adjusted for darker regions

        % Perform morphological operations to refine the mask in the ROI
        se = strel('rectangle', [3, 10]); % Adjusted structuring element
        refinedMask = imclose(darkRegionsMask, se); % Close gaps in vertical patterns
        refinedMask = bwareaopen(refinedMask, 100); % Remove small noise regions

        % Label connected components in the refined mask
        labeledRegions = bwconncomp(refinedMask);

        % Visualize all detected regions in the ROI
        figure; imshow(refinedMask); title('Detected Regions in ROI');
        hold on;
        stats = regionprops(labeledRegions, 'BoundingBox');
        for i = 1:length(stats)
            rectangle('Position', stats(i).BoundingBox, 'EdgeColor', 'g', 'LineWidth', 1);
        end
        hold off;

        % Measure properties of connected components
        regionProps = regionprops(labeledRegions, 'BoundingBox', 'Area', 'Centroid');

        % Initialize detection flag
        isBandDetected = false;

        % Process each detected region to find square-shaped bands
        for i = 1:length(regionProps)
            % Get region properties
            bbox = regionProps(i).BoundingBox;
            widthRegion = bbox(3);
            heightRegion = bbox(4);

            % Check for square bands (width and height should be nearly equal)
            if abs(widthRegion - heightRegion) < 10 && widthRegion > 5 && heightRegion > 5
                % Mark the region as a square band
                isBandDetected = true;
                break; % Stop checking once a valid square band is detected
            end
        end

        % Display final decision
        if isBandDetected
            disp('Square-shaped bands detected in the selected ROI. The currency is genuine.');
            % Show the message in a custom figure window
            display_message('The currency is genuine.', isGenuine);
        else
            disp('No square-shaped bands detected in the selected ROI. The currency may be counterfeit.');
            % Show the message in a custom figure window
            display_message('The currency may be counterfeit.', isGenuine);
        end
    else
        disp('Currency is counterfeit. Security thread detection skipped.');
        % Show the message in a custom figure window
        display_message('The currency is counterfeit.', isGenuine);
    end

elseif currency_value == 20
    % Define folders for each feature
    featureFolders = {'20 feature 1[value]', '20 feature 2[rbi seal]', '20 feature 3[reserve bank of india]', '20 feature 5[italic value]'};
    numFeatures = numel(featureFolders);

    % Convert the captured image to grayscale if necessary
    inputImageGray = im2gray(capturedImage);

    % Initialize result flag
    isGenuine = true;

    % Loop through each feature folder
    for f = 1:numFeatures
        featureFolder = featureFolders{f};
        featureMatched = false;

        % Get list of images in the current feature folder
        featureImages = dir(fullfile(featureFolder, '*.jpg'));

        % Detect features in the input image using SURF
        inputPoints = detectSURFFeatures(inputImageGray);
        [inputFeatures, inputValidPoints] = extractFeatures(inputImageGray, inputPoints);

        % Loop through each image in the feature folder
        for k = 1:numel(featureImages)
            % Load each feature image
            featureImage = imread(fullfile(featureFolder, featureImages(k).name));
            featureImageGray = rgb2gray(featureImage);

            % Detect features in the feature image using SURF
            featurePoints = detectSURFFeatures(featureImageGray);
            [featureFeatures, featureValidPoints] = extractFeatures(featureImageGray, featurePoints);

            % Match features between input image and feature image
            indexPairs = matchFeatures(inputFeatures, featureFeatures);

            % Check if there are enough matches
            if numel(indexPairs) >= 10
                featureMatched = true;

                % If the currency is genuine, display matched features
                if isGenuine
                    matchedInputPoints = inputValidPoints(indexPairs(:, 1));
                    matchedFeaturePoints = featureValidPoints(indexPairs(:, 2));

                    % Show matched features
                    figure('Name', ['Matched Features for ', featureImages(k).name]);
                    showMatchedFeatures(inputImageGray, featureImageGray, matchedInputPoints, matchedFeaturePoints, 'montage');
                    title(['Matched Features for: ', featureImages(k).name]);
                    axis image;
                end
                break;
            end
        end

        % If no match found for this feature, mark as counterfeit and exit loop
        if ~featureMatched
            isGenuine = false;
            fprintf('Feature %d did not match. The currency is counterfeit.\n', f);

            % Display the first unmatched feature image
            unmatchedFeatureImage = imread(fullfile(featureFolder, featureImages(1).name));
            figure('Name', ['Unmatched Feature: ', featureFolders{f}]);
            imshow(unmatchedFeatureImage);
            title(['Unmatched Feature: ', featureFolders{f}]);
            axis image;

            break;
        end
    end

    % If all features matched, proceed to security thread detection
    if isGenuine
        % Convert the image to HSV color space
        capturedImage=imresize(capturedImage, [750 1500]);
        hsvImage = rgb2hsv(capturedImage);

        % Extract the Value (V) channel
        valueChannel = hsvImage(:, :, 3);

        % Get the size of the image
        [height, width, ~] = size(capturedImage);

        % Define the crop size (e.g., 500x900 pixels)
        cropWidth = 160;  % Width of the cropped area
        cropHeight = 400; % Height of the cropped area

        % Calculate the coordinates for cropping around the center
        centerX = round(width / 2);  % X-coordinate of the image center
        centerY = round(height / 2); % Y-coordinate of the image center

        % Calculate the cropping rectangle [x, y, width, height]
        cropRect = [centerX + cropWidth / 2, centerY - cropHeight / 2, cropWidth, cropHeight];

        % Crop the Value channel image to the defined region
        roiImage = imcrop(valueChannel, cropRect);

        % Threshold to isolate dark regions (potential security thread) in the ROI
        darkRegionsMask = roiImage < 0.35; % Adjusted for darker regions

        % Perform morphological operations to refine the mask in the ROI
        se = strel('rectangle', [3, 10]); % Adjusted structuring element
        refinedMask = imclose(darkRegionsMask, se); % Close gaps in vertical patterns
        refinedMask = bwareaopen(refinedMask, 100); % Remove small noise regions

        % Label connected components in the refined mask
        labeledRegions = bwconncomp(refinedMask);

        % Visualize all detected regions in the ROI
        figure; imshow(refinedMask); title('Detected Regions in ROI');
        hold on;
        stats = regionprops(labeledRegions, 'BoundingBox');
        for i = 1:length(stats)
            rectangle('Position', stats(i).BoundingBox, 'EdgeColor', 'g', 'LineWidth', 1);
        end
        hold off;

        % Measure properties of connected components
        regionProps = regionprops(labeledRegions, 'BoundingBox', 'Area', 'Centroid');

        % Initialize detection flag
        isBandDetected = false;

        % Process each detected region to find square-shaped bands
        for i = 1:length(regionProps)
            % Get region properties
            bbox = regionProps(i).BoundingBox;
            widthRegion = bbox(3);
            heightRegion = bbox(4);

            % Check for square bands (width and height should be nearly equal)
            if abs(widthRegion - heightRegion) < 10 && widthRegion > 5 && heightRegion > 5
                % Mark the region as a square band
                isBandDetected = true;
                break; % Stop checking once a valid square band is detected
            end
        end

        % Display final decision
        if isBandDetected
            disp('Square-shaped bands detected in the selected ROI. The currency is genuine.');
            % Show the message in a custom figure window
            display_message('The currency is genuine.', isGenuine);
        else
            disp('No square-shaped bands detected in the selected ROI. The currency may be counterfeit.');
            % Show the message in a custom figure window
            display_message('The currency may be counterfeit.', isGenuine);
        end
    else
        disp('Currency is counterfeit. Security thread detection skipped.');
        % Show the message in a custom figure window
        display_message('The currency is counterfeit.', isGenuine);
    end

elseif currency_value == 10
    % Define folders for each feature
    featureFolders = {'10 feature 1[value]', '10 feature 2[rbi seal]', '10 feature 3[reserve bank of india]', '10 feature 5[italic value]'};
    numFeatures = numel(featureFolders);

    % Convert the captured image to grayscale if necessary
    inputImageGray = im2gray(capturedImage);

    % Initialize result flag
    isGenuine = true;

    % Loop through each feature folder
    for f = 1:numFeatures
        featureFolder = featureFolders{f};
        featureMatched = false;

        % Get list of images in the current feature folder
        featureImages = dir(fullfile(featureFolder, '*.jpg'));

        % Detect features in the input image using SURF
        inputPoints = detectSURFFeatures(inputImageGray);
        [inputFeatures, inputValidPoints] = extractFeatures(inputImageGray, inputPoints);

        % Loop through each image in the feature folder
        for k = 1:numel(featureImages)
            % Load each feature image
            featureImage = imread(fullfile(featureFolder, featureImages(k).name));
            featureImageGray = rgb2gray(featureImage);

            % Detect features in the feature image using SURF
            featurePoints = detectSURFFeatures(featureImageGray);
            [featureFeatures, featureValidPoints] = extractFeatures(featureImageGray, featurePoints);

            % Match features between input image and feature image
            indexPairs = matchFeatures(inputFeatures, featureFeatures);

            % Check if there are enough matches
            if numel(indexPairs) >= 10
                featureMatched = true;

                % If the currency is genuine, display matched features
                if isGenuine
                    matchedInputPoints = inputValidPoints(indexPairs(:, 1));
                    matchedFeaturePoints = featureValidPoints(indexPairs(:, 2));

                    % Show matched features
                    figure('Name', ['Matched Features for ', featureImages(k).name]);
                    showMatchedFeatures(inputImageGray, featureImageGray, matchedInputPoints, matchedFeaturePoints, 'montage');
                    title(['Matched Features for: ', featureImages(k).name]);
                    axis image;
                end
                break;
            end
        end

        % If no match found for this feature, mark as counterfeit and exit loop
        if ~featureMatched
            isGenuine = false;
            fprintf('Feature %d did not match. The currency is counterfeit.\n', f);

            % Display the first unmatched feature image
            unmatchedFeatureImage = imread(fullfile(featureFolder, featureImages(1).name));
            figure('Name', ['Unmatched Feature: ', featureFolders{f}]);
            imshow(unmatchedFeatureImage);
            title(['Unmatched Feature: ', featureFolders{f}]);
            axis image;

            break;
        end
    end

    % If all features matched, proceed to security thread detection
    if isGenuine
        % Convert the image to HSV color space
        capturedImage=imresize(capturedImage, [750,1450]);
        hsvImage = rgb2hsv(capturedImage);

        % Extract the Value (V) channel
        valueChannel = hsvImage(:, :, 3);

        % Get the size of the image
        [height, width, ~] = size(capturedImage);

        % Define the crop size (e.g., 500x900 pixels)
        cropWidth = 160;  % Width of the cropped area
        cropHeight = 400; % Height of the cropped area

        % Calculate the coordinates for cropping around the center
        centerX = round(width / 2);  % X-coordinate of the image center
        centerY = round(height / 2); % Y-coordinate of the image center

        % Calculate the cropping rectangle [x, y, width, height]
        cropRect = [centerX + cropWidth / 2, centerY - cropHeight / 2, cropWidth, cropHeight];

        % Crop the Value channel image to the defined region
        roiImage = imcrop(valueChannel, cropRect);

        % Threshold to isolate dark regions (potential security thread) in the ROI
        darkRegionsMask = roiImage < 0.35; % Adjusted for darker regions

        % Perform morphological operations to refine the mask in the ROI
        se = strel('rectangle', [3, 10]); % Adjusted structuring element
        refinedMask = imclose(darkRegionsMask, se); % Close gaps in vertical patterns
        refinedMask = bwareaopen(refinedMask, 100); % Remove small noise regions

        % Label connected components in the refined mask
        labeledRegions = bwconncomp(refinedMask);

        % Visualize all detected regions in the ROI
        figure; imshow(refinedMask); title('Detected Regions in ROI');
        hold on;
        stats = regionprops(labeledRegions, 'BoundingBox');
        for i = 1:length(stats)
            rectangle('Position', stats(i).BoundingBox, 'EdgeColor', 'g', 'LineWidth', 1);
        end
        hold off;

        % Measure properties of connected components
        regionProps = regionprops(labeledRegions, 'BoundingBox', 'Area', 'Centroid');

        % Initialize detection flag
        isBandDetected = false;

        % Process each detected region to find square-shaped bands
        for i = 1:length(regionProps)
            % Get region properties
            bbox = regionProps(i).BoundingBox;
            widthRegion = bbox(3);
            heightRegion = bbox(4);

            % Check for square bands (width and height should be nearly equal)
            if abs(widthRegion - heightRegion) < 10 && widthRegion > 5 && heightRegion > 5
                % Mark the region as a square band
                isBandDetected = true;
                break; % Stop checking once a valid square band is detected
            end
        end

        % Display final decision
        if isBandDetected
            disp('Square-shaped bands detected in the selected ROI. The currency is genuine.');
            % Show the message in a custom figure window
            display_message('The currency is genuine.', isGenuine);
        else
            disp('No square-shaped bands detected in the selected ROI. The currency may be counterfeit.');
            % Show the message in a custom figure window
            display_message('The currency is counterfeit.', isGenuine);
        end
    else
        disp('Currency is counterfeit. Security thread detection skipped.');
        % Show the message in a custom figure window
        display_message('The currency is counterfeit.', isGenuine);
    end

end

% Function to display the message window and provide audio feedback
function display_message(message, isGenuine)
    % Display the message in a custom figure window
    if isGenuine
        figure('Name', 'Result', 'NumberTitle', 'off', 'Position', [500, 500, 400, 200]);
        uicontrol('Style', 'text', 'String', message, 'Position', [50, 100, 300, 40], 'FontSize', 14, 'FontWeight', 'bold', 'BackgroundColor', [0.8 1 0.8], 'HorizontalAlignment', 'center');
    else
        figure('Name', 'Result', 'NumberTitle', 'off', 'Position', [500, 500, 400, 200]);
        uicontrol('Style', 'text', 'String', message, 'Position', [50, 100, 300, 40], 'FontSize', 14, 'FontWeight', 'bold', 'BackgroundColor', [1 0.8 0.8], 'HorizontalAlignment', 'center');
    end

    % Pause to allow window rendering before playing the sound
    pause(0.1);
    
    % Provide audio feedback after displaying the message
    provide_audio_feedback(message);
end

% Function to provide audio feedback
function provide_audio_feedback(message)
    if ispc
        % Use built-in 'System.Speech.Synthesis.SpeechSynthesizer' for Windows
        NET.addAssembly('System.Speech');
        speaker = System.Speech.Synthesis.SpeechSynthesizer;
        speaker.Speak(message);
    else
        % Use audioplayer for systems without TTS
        fs = 44100;  % Sampling frequency
        y = tts(message, fs);  % Convert text to speech
        sound(y, fs);  % Play the sound
    end
end
