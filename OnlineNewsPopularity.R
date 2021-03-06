#Importing libraries
library(caTools)
library(rpart)
library(compare)
library(caret)
library(lattice)
library(ggplot2)
library(e1071)
library(pROC)
library(ROCR)

# Read the csv file into a dataframe
dataset <- read.csv("OnlineNewsPopularity.csv", header = TRUE)
dataset2 <- read.csv("OnlineNewsPopularity.csv", header = TRUE)


# Removing NA values from the data, if any
dataset <- na.omit(dataset)

# Cleaning the dataset by removing columns that are not used in the analysis
dataset <- dataset[ -c(1,2,40:60)]

#Restructuring columns in df to get rid of data redundancy

# Replacing columns like is_monday, is_tuesday, etc to a single columns whivh indicates what day of the week an article was published.
dataset$Day <- ifelse(dataset$weekday_is_monday == 1, "monday",      	 
                      ifelse((dataset$weekday_is_tuesday == 1), "tuesday",
                             ifelse((dataset$weekday_is_wednesday == 1), "wednesday",
                                    ifelse((dataset$weekday_is_thursday == 1), "thursday",
                                           ifelse((dataset$weekday_is_friday == 1), "friday",  
                                                  ifelse((dataset$weekday_is_saturday == 1), "saturday", "sunday"))))))

dataset$Day <- factor(dataset$Day,
                      levels=c('monday','tuesday','wednesday','thursday','friday','saturday','sunday'),
                      labels=c(1,2,3,4,5,6,7))

# Doing the same with data channels as we did with days columns
dataset$dataChannel <- ifelse(dataset$data_channel_is_lifestyle == 1,"lifestyle",
                              ifelse(dataset$data_channel_is_entertainment == 1,"entertainment",
                                     ifelse(dataset$data_channel_is_bus == 1,"business",
                                            ifelse(dataset$data_channel_is_socmed == 1,"Social",
                                                   ifelse(dataset$data_channel_is_tech == 1,"tech", "world")))))

dataset$dataChannel <- factor(dataset$dataChannel,
                              levels=c('lifestyle','entertainment','business','Social','tech','world'),
                              labels=c(1,2,3,4,5,6))

# Removing the extra columns
dataset <- dataset[,-c(12:17, 30:36)]

# Figuring out significant attributes using correlation matrix of share attribute with other attributes
library(caTools)
correlation<-as.data.frame(as.table(cor( dataset2[,-c(dataset2$shares)], dataset2$shares)))
names(correlation)<-c("Attribute","Shares", "Correlation with shares attribute")
correlation<-correlation[-c(2)]
dataset$shares = as.numeric(dataset$shares)

#Classifying articles into two categories based on median of shares
dataset$popularity <- ifelse(dataset$shares <=1400, "low","high")

#Splitting the data into training and test sets 75:25 proportion
split = sample.split(dataset$shares, SplitRatio = 0.75)
training_set = subset(dataset, split == TRUE)
test_set = subset(dataset, split == FALSE)



#CART implementation
analysis<-rpart(training_set$ popularity~ kw_max_avg +  self_reference_avg_sharess + self_reference_min_shares + self_reference_max_shares + kw_avg_max + kw_min_avg + num_imgs + kw_max_min + num_videos + num_keywords + is_weekend , data=training_set)
plot(analysis, uniform = TRUE, margin = 0.2)
text(analysis)

#Confusion Matrix for CART training set
ctrain <- as.data.frame(predict(analysis,newdata = training_set))
ctrain$popularity <- ifelse(ctrain$low >= 0.5, "low","high")

lvs <- c("positive", "negative")
truth <- factor(rep(lvs, times = c(30, 2000)),
                levels = rev(lvs))
pred <- factor(
  c(
    rep(lvs, times = c(20, 10)),
    rep(lvs, times = c(180, 1820))),               
  levels = rev(lvs))

xtab <- table(ctrain$popularity, training_set$popularity)
print(confusionMatrix(xtab[2:1,2:1]))

#Confusion Matrix for CART test set
ctest <- as.data.frame(predict(analysis,newdata = test_set))
ctest$popularity <- ifelse(ctest$low >= 0.5, "low","high")

lvs <- c("positive", "negative")
truth <- factor(rep(lvs, times = c(30, 2000)),
                levels = rev(lvs))
pred <- factor(
  c(
    rep(lvs, times = c(20, 10)),
    rep(lvs, times = c(180, 1820))),               
  levels = rev(lvs))

xtab <- table(ctest$popularity, test_set$popularity)
print(confusionMatrix(xtab[2:1,2:1]))

#Naive Bayes Model
news_naive_bayes = train(popularity ~ kw_max_avg + self_reference_avg_sharess + self_reference_min_shares + self_reference_max_shares + kw_avg_max+kw_min_avg + num_imgs + kw_max_min + num_videos + num_keywords + is_weekend , data=training_set , method= "nb",  trControl=trainControl(method="cv", number=10))
news_naive_bayes


#Confusion Matrix for Naive Bayes training set
ntrain <- as.data.frame(predict(news_naive_bayes,newdata = training_set))
ntrain$popularity <- ifelse(ntrain$low >= 0.5, "low","high")

lvs <- c("positive", "negative")
truth <- factor(rep(lvs, times = c(30, 2000)),
                levels = rev(lvs))
pred <- factor(
  c(
    rep(lvs, times = c(20, 10)),
    rep(lvs, times = c(180, 1820))),               
  levels = rev(lvs))

xtab <- table(ntrain$popularity, training_set$popularity)
print(confusionMatrix(xtab[2:1,2:1]))

#Confusion Matrix for Naive Bayes test set
ctest <- as.data.frame(predict(news_naive_bayes,newdata = test_set))
ctest$popularity <- ifelse(ctest$low >= 0.5, "low","high")

lvs <- c("positive", "negative")
truth <- factor(rep(lvs, times = c(30, 2000)),
                levels = rev(lvs))
pred <- factor(
  c(
    rep(lvs, times = c(20, 10)),
    rep(lvs, times = c(180, 1820))),               
  levels = rev(lvs))

xtab <- table(ctest$popularity, test_set$popularity)
print(confusionMatrix(xtab[2:1,2:1]))

#ROC curve for CART
class_cart<-predict( analysis,test_set ,type="class")
prob_cart<-predict( analysis,test_set ,type="prob")
roc_cart <- roc(test_set$popularity,prob_cart[,2])
plot(roc_cart, xlab='False Positive Rate', ylab='True Positive Rate', main='CART')

#ROC curve for Naive Bayes 
prob_nb<-predict(news_naive_bayes,test_set ,type="prob")
roc_nb <- roc(test_set$popularity,prob_nb[,2])
plot(roc_nb, xlab='False Positive Rate', ylab='True Positive Rate', main='Naive Bayes')

#Combining both ROC curves
ROCCurve<-par(pty = "s")
plot(performance(prediction(prob_cart[,2],test_set$popularity),'tpr','fpr'))
plot(performance(prediction(prob_cart[,2],test_set$popularity),'tpr','fpr'),
     col="blue", lwd=3, add=TRUE)
text(0.40,0.25,"CART",col="blue")

plot(performance(prediction(prob_nb[,2],test_set$popularity),'tpr','fpr'),
     col="red", lwd=3, add=TRUE)
text(0.70,0.50,"NAIVE BAYES",col="red")