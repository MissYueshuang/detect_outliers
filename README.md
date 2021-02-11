# fs_outlier_with_BBG
Detect financial statement outliers from database and compare them with Bloomberg 
<br />
Main Function: OutlierDetection.mat
<br />
<br />
Step1: Use 3 methods to identify possible outliers in our system: using exponential distribution; by relative change; by TZ-score and Local Outlier Factor(LOF).
<br />
Step2: Use Bloomberg API to verify if those suspicious outliers are truly different from bbg terminal.

<br />
PS. Due to certain internal requirement, I have to use both matlab and python for this project.
