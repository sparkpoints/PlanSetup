# PlanSetup(orignal name:IMRT_Perl)

This program is used to setup init parameter for the radiation plans in Pinnacle 3 TPS(philips cop)。该程序由Pinnacle3 TPS的API脚本和Perl程序组成，用于协助放疗剂量师快速的设置放疗计划初始设置，包括:点、轮廓、射野、剂量和逆向优化目标等。

与Pinnacle3 的静态脚本相比，本项目特点是：依据肿瘤位置、危机器官和剂量参数，匹配计划的要求，自动生成：1，轮廓假体；2，射野角度；3，靶区和危机器官的初始逆向优化参数。辅助功能包括：计划预设值检测；等剂量曲线（ISO dose line）；DVH标记等辅助功能。

## 程序框架(main process)

1. Checking OAR,Then modifying OAR names to standard's names(marking DVH display enable)
2. using Xtermal,dose prescription
        List avliable Targets, making default choice
        prescription and fraction number
        TotalDose(3000,4500,6000),Isodose Lines,PrescritionDose
3. Adapting OAR, then Set Beams numbers and angles
4. Create Opti_PRV
        PTV_PRV
        OverLap Phantom
        VIP_OAR
        NormalTissure
5. CommonSetting, Iso to Ref distance
6. searching OAR,then add optimization target lists.

#TODO

1. Python Replace Perl
2. Auto Optimization process
first:building the result assertion model(according to Pinnacle Challenge model)
then :assertion model adjusting the optimization parameters
