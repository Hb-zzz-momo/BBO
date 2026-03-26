

clc
clear
close all
%%
for Function_name = 1:30
nPop = 30 ; % number of population
Max_iter = 500 ; % maximum number of iterations
dim = 30 ; % The value can be 2, 10, 30, 50, 100

%%  select function
% Function_name= 30 ; % function name： 1 - 30
[lb,ub,dim,fobj] = Get_Functions_cec2017(Function_name,dim);




%% Beaver Behavior Optimizer
tic
[BBO_Best_score,BBO_Best_pos,BBO_cg_curve]=BBO(nPop,Max_iter,lb,ub,dim,fobj);
toc
display(['The best optimal value of the objective funciton found by BBO  for F' [num2str(Function_name)],' is: ', num2str(BBO_Best_score)]);
fprintf ('Best solution obtained by BBO: %s\n', num2str(BBO_Best_pos,'%e  '));
%% plot
% figure('Position',[400 200 300 250])
figure


semilogy(BBO_cg_curve,'y','Linewidth',2)

title(['CEC2017-F',num2str(Function_name), ' (Dim=' num2str(dim), ')'])
xlabel('Iteration');
ylabel(['Best score F' num2str(Function_name) ]);
axis tight
grid on
box on
set(gca,'color','none')
legend('BBO')
pause(1)
end
