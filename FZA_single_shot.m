clearvars; clc; close all
% FZA_lensless_imaging
addpath('./functions');  %向搜索路径中添加文件夹

%% Pingole imaging
% img = im2double(imread('THU.png'));  %将图像转换为双精度，A = imread(filename) 从 filename 指定的文件读取图像，并从文件内容推断出其格式。如果 filename 为多图像文件，则 imread 读取该文件中的第一个图像。
img = im2double(imread('cameraman.tif'));

di = 3;         % the distance from mask to sensor，掩膜与传感器的间距
z1 = 20;    x1 = 0;    y1 = 0;

Lx1 = 20;       % object size，对象大小

dp = 0.01;      % pixel pitch，像素间距
Nx = 512;       % pixel numbers，像素数量
Ny = 512;

% generate the original imaging to be reconstructed，生成待重建的原始图像
Im = pinhole(img,di,x1,y1,z1,Lx1,dp,Nx);
figure,imagesc(Im);title('Original image')
colormap gray;
axis image off

%% Imaging processing
S = 2*dp*Nx;        % aperture diameter
r1 = 0.23;          % FZA constant

M = di/z1;
ri = (1+M)*r1;

mask = FZA(S,2*Nx,ri);  % generate the FZA mask

I = conv2(Im,mask,'same')*2*dp*dp/ri^2; % 2*dp*dp/ri^2 ensure the values are same with I1
I = I - mean(I(:));

figure,imagesc(mask);title('FZA pattern')
colormap gray;
axis image off
figure,imagesc(I);title('Observed imaging')
colormap gray;
axis image off

%% back propagation

fu_max = 0.5 / dp;
fv_max = 0.5 / dp;
du = 2*fu_max / (Nx);
dv = 2*fv_max / (Ny);

[u,v] = meshgrid(-fu_max:du:fu_max-du,-fv_max:dv:fv_max-dv);
H = 1i*exp(-1i*(pi*ri^2)*(u.^2 + v.^2));  % fresnel transfer function 

Or = MyAdjointOperatorPropagation(I,H);

figure,imagesc(real(Or));title('Reconstructed image (BP)')
colormap gray;
axis equal off tight

%% Propagation operator 
A = @(obj) MyForwardOperatorPropagation(obj,H);  % forward propagation operator
AT = @(I) MyAdjointOperatorPropagation(I,H);  % backward propagation operator

%% TwIST algorithm 

% denoising function;
tv_iters = 2;
Psi = @(x,th) tvdenoise(x,2/th,tv_iters);
% TV regularizer;
Phi = @(x) TVnorm(x);

tau = 0.005; 
tolA = 1e-6;
iterations = 200;
[f_reconstruct,dummy,obj_twist,...
    times_twist,dummy,mse_twist]= ...
    TwIST(I,A,tau,...
    'AT', AT, ...
    'Psi',Psi,...
    'Phi',Phi,...
    'Initialization',2,...
    'Monotone',1,...
    'StopCriterion',1,...
    'MaxIterA',iterations,...
    'MinIterA',iterations,...
    'ToleranceA',tolA,...
    'Verbose', 1);

figure;imagesc(real(f_reconstruct));title('Reconstructed image (CS)')
colormap gray;
axis image off
