if(getRversion() >= "2.15.1") utils::globalVariables(c(".", "X.weights."))

#' Plot Conditional Coefficients in Mixed-Effects Models with Interaction Terms 
#' 
#' \code{interplot.mlm} is a method to calculate conditional coefficient estimates from the results of multilevel (mixed-effects) regression models with interaction terms. 
#' 
#' @param m A model object including an interaction term, or, alternately, a data frame recording conditional coefficients.
#' @param var1 The name (as a string) of the variable of interest in the interaction term; its conditional coefficient estimates will be plotted.
#' @param var2 The name (as a string) of the other variable in the interaction term.
#' @param plot A logical value indicating whether the output is a plot or a dataframe including the conditional coefficient estimates of var1, their upper and lower bounds, and the corresponding values of var2.
#' @param steps Desired length of the sequence. A non-negative number, which for seq and seq.int will be rounded up if fractional. The default is 100 or the unique categories in the \code{var2} (when it is less than 100. Also see \code{\link{unique}}).
#' @param ci A numeric value defining the confidence intervals. The default value is 95\% (0.95).
#' @param adjCI Not working for `lmer` outputs yet.
#' @param hist A logical value indicating if there is a histogram of `var2` added at the bottom of the conditional effect plot.
#' @param var2_dt A numerical value indicating the frequency distribution of `var2`. It is only used when `hist == TRUE`. When the object is a model, the default is the distribution of `var2` of the model. 
#' @param predPro A logical value with default of `FALSE`. When the `m` is an object of class `glmerMod` and the argument is set to `TRUE`, the function will plot predicted probabilities at the values given by `var2_vals`. 
#' @param var2_vals A numerical value indicating the values the predicted probabilities are estimated, when `predPro` is `TRUE`. 
#' @param point A logical value determining the format of plot. By default, the function produces a line plot when var2 takes on ten or more distinct values and a point (dot-and-whisker) plot otherwise; option TRUE forces a point plot.
#' @param sims Number of independent simulation draws used to calculate upper and lower bounds of coefficient estimates: lower values run faster; higher values produce smoother curves.
#' @param xmin A numerical value indicating the minimum value shown of x shown in the graph. Rarely used.
#' @param xmax A numerical value indicating the maximum value shown of x shown in the graph. Rarely used.
#' @param ercolor A character value indicating the outline color of the whisker or ribbon.
#' @param esize A numerical value indicating the size of the whisker or ribbon.
#' @param ralpha A numerical value indicating the transparency of the ribbon.
#' @param rfill A character value indicating the filling color of the ribbon.
#' @param ... Other ggplot aesthetics arguments for points in the dot-whisker plot or lines in the line-ribbon plots. Not currently used.
#' 
#' @details \code{interplot.mlm} is a S3 method from the \code{interplot}. It works on mixed-effects objects with class \code{lmerMod} and \code{glmerMod}.
#' 
#' Because the output function is based on \code{\link[ggplot2]{ggplot}}, any additional arguments and layers supported by \code{ggplot2} can be added with the \code{+}. 
#' 
#' @return The function returns a \code{ggplot} object.
#' 
#' @importFrom  arm sim
#' @importFrom stats quantile
#' @importFrom stats median
#' @importFrom stats plogis
#' @importFrom stats model.matrix
#' @importFrom purrr map
#' @import  ggplot2
#' @import  dplyr
#' 
#' 
#' @export


# Coding function for non-mi mlm objects
interplot.lmerMod <- function(m, var1, var2, plot = TRUE, steps = NULL, ci = .95, adjCI = FALSE,hist = FALSE, var2_dt = NA, predPro = FALSE, var2_vals = NULL, point = FALSE, sims = 5000,xmin = NA, xmax = NA, ercolor = NA, esize = 0.5, ralpha = 0.5, rfill = "grey70", ...) {
    #set.seed(324)
    
    m.class <- class(m)
    
    if(predPro == TRUE) stop("Predicted probability is estimated only for general linear models.")
    
    
    m.sims <- arm::sim(m, sims)
    
    ### For factor base terms###
    factor_v1 <- factor_v2 <- FALSE
    
    if (is.factor(eval(parse(text = paste0("m@frame$", var1)))) & is.factor(eval(parse(text = paste0("m@frame$", 
        var2))))) 
        stop("The function does not support interactions between two factors.")
    
    if (is.factor(eval(parse(text = paste0("m@frame$", var1))))) {
        var1_bk <- var1
        var1 <- paste0(var1, levels(eval(parse(text = paste0("m@frame$", 
            var1)))))
        factor_v1 <- TRUE
        ifelse(var1 == var2, var12 <- paste0("I(", var1, "^2)"), var12 <- paste0(var2, 
            ":", var1)[-1])
        
        # the first category is censored to avoid multicolinarity
        for (i in seq(var12)) {
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                var12[i] <- paste0(var1, ":", var2)[-1][i]
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                stop(paste("Model does not include the interaction of", 
                  var1, "and", var2, "."))
        }
    } else if (is.factor(eval(parse(text = paste0("m@frame$", var2))))) {
        var2_bk <- var2
        var2 <- paste0(var2, levels(eval(parse(text = paste0("m@frame$", 
            var2)))))
        factor_v2 <- TRUE
        ifelse(var1 == var2, var12 <- paste0("I(", var1, "^2)"), var12 <- paste0(var2, 
            ":", var1)[-1])
        
        # the first category is censored to avoid multicolinarity
        for (i in seq(var12)) {
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                var12[i] <- paste0(var1, ":", var2)[-1][i]
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                stop(paste("Model does not include the interaction of", 
                  var1, "and", var2, "."))
        }
    } else {
        ifelse(var1 == var2, var12 <- paste0("I(", var1, "^2)"), var12 <- paste0(var2, 
            ":", var1))
        
        # the first category is censored to avoid multicolinarity
        for (i in seq(var12)) {
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                var12[i] <- paste0(var1, ":", var2)[i]
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                stop(paste("Model does not include the interaction of", 
                  var1, "and", var2, "."))
        }
    }
    
    ################### 
    
    if (factor_v2) {
        xmin <- 0
        xmax <- 1
        steps <- 2
    } else {
        if (is.na(xmin)) 
            xmin <- min(m@frame[var2], na.rm = T)
        if (is.na(xmax)) 
            xmax <- max(m@frame[var2], na.rm = T)
        
        if (is.null(steps)) {
          steps <- eval(parse(text = paste0("length(unique(na.omit(m@frame$", 
                                            var2, ")))")))
        }
        
        if (steps > 100) 
            steps <- 100  # avoid redundant calculation
    }
    
    coef <- data.frame(fake = seq(xmin, xmax, length.out = steps), coef1 = NA, 
        ub = NA, lb = NA)
    coef_df <- data.frame(fake = numeric(0), coef1 = numeric(0), ub = numeric(0), 
        lb = numeric(0), model = character(0))
    
    if (factor_v1) {
        for (j in 1:(length(levels(eval(parse(text = paste0("m@frame$", 
            var1_bk))))) - 1)) {
            # only n - 1 interactions; one category is avoided against
            # multicolinarity
            
            for (i in 1:steps) {
                coef$coef1[i] <- mean(m.sims@fixef[, match(var1[j + 1], 
                  unlist(dimnames(m@pp$X)[2]))] + coef$fake[i] * m.sims@fixef[, 
                  match(var12[j], unlist(dimnames(m@pp$X)[2]))])
                coef$ub[i] <- quantile(m.sims@fixef[, match(var1[j + 1], 
                  unlist(dimnames(m@pp$X)[2]))] + coef$fake[i] * m.sims@fixef[, 
                  match(var12[j], unlist(dimnames(m@pp$X)[2]))], (1 - ci) / 2)
                coef$lb[i] <- quantile(m.sims@fixef[, match(var1[j + 1], 
                  unlist(dimnames(m@pp$X)[2]))] + coef$fake[i] * m.sims@fixef[, 
                  match(var12[j], unlist(dimnames(m@pp$X)[2]))], 1 - (1 - ci) / 2)
            }
            
            if (plot == TRUE) {
                coef$value <- var1[j + 1]
                coef_df <- rbind(coef_df, coef)
                if (hist == TRUE) {
                  if (is.na(var2_dt)) {
                    var2_dt <- eval(parse(text = paste0("m@frame$", var2)))
                  } else {
                    var2_dt <- var2_dt
                  }
                }
            } else {
                names(coef) <- c(var2, "coef", "ub", "lb")
                return(coef)
            }
        }
        coef_df$value <- as.factor(coef_df$value)
        interplot.plot(m = coef_df, hist = hist, var2_dt = var2_dt, point = point, 
            ercolor = ercolor, esize = esize, ralpha = ralpha, rfill = rfill, 
            ...) + facet_grid(. ~ value)
        
    } else if (factor_v2) {
        for (j in 1:(length(levels(eval(parse(text = paste0("m@frame$", 
            var2_bk))))) - 1)) {
            # only n - 1 interactions; one category is avoided against
            # multicolinarity
            
            for (i in 1:steps) {
                coef$coef1[i] <- mean(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))])
                coef$ub[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))], 
                  (1 - ci) / 2)
                coef$lb[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))], 
                  1 - (1 - ci) / 2)
            }
            
            if (plot == TRUE) {
                coef$value <- var2[j + 1]
                coef_df <- rbind(coef_df, coef)
                if (hist == TRUE) {
                  if (is.na(var2_dt)) {
                    var2_dt <- eval(parse(text = paste0("m@frame$", var2)))
                  } else {
                    var2_dt <- var2_dt
                  }
                }
            } else {
                names(coef) <- c(var2, "coef", "ub", "lb")
                return(coef)
            }
        }
        coef_df$value <- as.factor(coef_df$value)
        interplot.plot(m = coef_df, hist = hist, var2_dt = var2_dt, point = point, 
            ercolor = ercolor, esize = esize, ralpha = ralpha, rfill = rfill, 
            ...) + facet_grid(. ~ value)
        
        
    } else {
        ## Correct marginal effect for quadratic terms
        multiplier <- if (var1 == var2) 
            2 else 1
        
        for (i in 1:steps) {
            coef$coef1[i] <- mean(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                multiplier * coef$fake[i] * m.sims@fixef[, match(var12, 
                  unlist(dimnames(m@pp$X)[2]))])
            coef$ub[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                multiplier * coef$fake[i] * m.sims@fixef[, match(var12, 
                  unlist(dimnames(m@pp$X)[2]))], (1 - ci) / 2)
            coef$lb[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                multiplier * coef$fake[i] * m.sims@fixef[, match(var12, 
                  unlist(dimnames(m@pp$X)[2]))], 1 - (1 - ci) / 2)
        }
        
        multiplier <- if (var1 == var2) 
          2 else 1
        
        min_sim <- m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
          multiplier * xmin * m.sims@fixef[, match(var12, unlist(dimnames(m@pp$X)[2]))] # simulation of the value at the minimum value of the conditioning variable
        max_sim <- m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
          multiplier * xmax * m.sims@fixef[, match(var12, unlist(dimnames(m@pp$X)[2]))] # simulation of the value at the maximum value of the conditioning variable
        diff <- max_sim - min_sim # calculating the difference
        ci_diff <- c(
          quantile(diff, (1 - ci) / 2),
          quantile(diff, 1 - (1 - ci) / 2)
        ) # confidence intervals of the difference
        
        if (plot == TRUE) {
            if (hist == TRUE) {
                if (is.na(var2_dt)) {
                  var2_dt <- eval(parse(text = paste0("m@frame$", var2)))
                } else {
                  var2_dt <- var2_dt
                }
            }
            interplot.plot(m = coef, hist = hist, var2_dt = var2_dt, point = point, 
                ercolor = ercolor, esize = esize, ralpha = ralpha, rfill = rfill, ci_diff = ci_diff, ...)
        } else {
            names(coef) <- c(var2, "coef", "ub", "lb")
            return(coef)
        }
        
    }
}

#' @export
interplot.glmerMod <- function(m, var1, var2, plot = TRUE, steps = NULL, ci = .95, adjCI = FALSE, hist = FALSE, var2_dt = NA, predPro = FALSE, var2_vals = NULL, point = FALSE, sims = 5000, xmin = NA, xmax = NA, ercolor = NA, esize = 0.5, ralpha = 0.5, rfill = "grey70", ...) {
    #set.seed(324)
    
    m.class <- class(m)
    m.sims <- arm::sim(m, sims)
    
    
    ### For factor base terms###
    factor_v1 <- factor_v2 <- FALSE
    
    if (is.factor(eval(parse(text = paste0("m@frame$", var1)))) & is.factor(eval(parse(text = paste0("m@frame$", 
        var2))))) 
        stop("The function does not support interactions between two factors.")
    
    if (is.factor(eval(parse(text = paste0("m@frame$", var1))))) {
        var1_bk <- var1
        var1 <- paste0(var1, levels(eval(parse(text = paste0("m@frame$", 
            var1)))))
        factor_v1 <- TRUE
        ifelse(var1 == var2, var12 <- paste0("I(", var1, "^2)"), var12 <- paste0(var2, 
            ":", var1)[-1])
        
        # the first category is censored to avoid multicolinarity
        for (i in seq(var12)) {
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                var12[i] <- paste0(var1, ":", var2)[-1][i]
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                stop(paste("Model does not include the interaction of", 
                  var1, "and", var2, "."))
        }
    } else if (is.factor(eval(parse(text = paste0("m@frame$", var2))))) {
        var2_bk <- var2
        var2 <- paste0(var2, levels(eval(parse(text = paste0("m@frame$", 
            var2)))))
        factor_v2 <- TRUE
        ifelse(var1 == var2, var12 <- paste0("I(", var1, "^2)"), var12 <- paste0(var2, 
            ":", var1)[-1])
        
        # the first category is censored to avoid multicolinarity
        for (i in seq(var12)) {
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                var12[i] <- paste0(var1, ":", var2)[-1][i]
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                stop(paste("Model does not include the interaction of", 
                  var1, "and", var2, "."))
        }
    } else {
        ifelse(var1 == var2, var12 <- paste0("I(", var1, "^2)"), var12 <- paste0(var2, 
            ":", var1))
        
        # the first category is censored to avoid multicolinarity
        for (i in seq(var12)) {
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                var12[i] <- paste0(var1, ":", var2)[i]
            if (!var12[i] %in% unlist(dimnames(m@pp$X)[2])) 
                stop(paste("Model does not include the interaction of", 
                  var1, "and", var2, "."))
        }
    }
    
    ################### 
    
    if (factor_v2) {
        xmin <- 0
        xmax <- 1
        steps <- 2
    } else {
        if (is.na(xmin)) 
            xmin <- min(m@frame[var2], na.rm = T)
        if (is.na(xmax)) 
            xmax <- max(m@frame[var2], na.rm = T)
        
        if (is.null(steps)) {
          steps <- eval(parse(text = paste0("length(unique(na.omit(m@frame$", 
                                            var2, ")))")))
        }
        
        if (steps > 100) 
            steps <- 100  # avoid redundant calculation
    }
    
    coef <- data.frame(fake = seq(xmin, xmax, length.out = steps), coef1 = NA, 
        ub = NA, lb = NA)
    coef_df <- data.frame(fake = numeric(0), coef1 = numeric(0), ub = numeric(0), 
        lb = numeric(0), model = character(0))
    
    if (factor_v1) {
      
      if(predPro == TRUE) stop("The current version does not support estimating predicted probabilities for factor base terms.")
      
      
        for (j in 1:(length(levels(eval(parse(text = paste0("m@frame$", 
            var1_bk))))) - 1)) {
            # only n - 1 interactions; one category is avoided against
            # multicolinarity
            
            for (i in 1:steps) {
                coef$coef1[i] <- mean(m.sims@fixef[, match(var1[j + 1], 
                  unlist(dimnames(m@pp$X)[2]))] + coef$fake[i] * m.sims@fixef[, 
                  match(var12[j], unlist(dimnames(m@pp$X)[2]))])
                coef$ub[i] <- quantile(m.sims@fixef[, match(var1[j + 1], 
                  unlist(dimnames(m@pp$X)[2]))] + coef$fake[i] * m.sims@fixef[, 
                  match(var12[j], unlist(dimnames(m@pp$X)[2]))], (1 - ci) / 2)
                coef$lb[i] <- quantile(m.sims@fixef[, match(var1[j + 1], 
                  unlist(dimnames(m@pp$X)[2]))] + coef$fake[i] * m.sims@fixef[, 
                  match(var12[j], unlist(dimnames(m@pp$X)[2]))], 1 - (1 - ci) / 2)
            }
            
            if (plot == TRUE) {
                coef$value <- var1[j + 1]
                coef_df <- rbind(coef_df, coef)
                if (hist == TRUE) {
                  if (is.na(var2_dt)) {
                    var2_dt <- eval(parse(text = paste0("m@frame$", var2)))
                  } else {
                    var2_dt <- var2_dt
                  }
                }
            } else {
                names(coef) <- c(var2, "coef", "ub", "lb")
                return(coef)
            }
        }
        coef_df$value <- as.factor(coef_df$value)
        interplot.plot(m = coef_df, hist = hist, steps = steps, var2_dt = var2_dt, point = point, 
            ercolor = ercolor, esize = esize, ralpha = ralpha, rfill = rfill, 
            ...) + facet_grid(. ~ value)
        
    } else if (factor_v2) {
      
      if(predPro == TRUE) stop("The current version does not support estimating predicted probabilities for factor base terms.")
      
        for (j in 1:(length(levels(eval(parse(text = paste0("m@frame$", 
            var2_bk))))) - 1)) {
            # only n - 1 interactions; one category is avoided against
            # multicolinarity
            
            for (i in 1:steps) {
                coef$coef1[i] <- mean(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))])
                coef$ub[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))], 
                  (1 - ci) / 2)
                coef$lb[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                  coef$fake[i] * m.sims@fixef[, match(var12[j], unlist(dimnames(m@pp$X)[2]))], 
                  1 - (1 - ci) / 2)
            }
            
            if (plot == TRUE) {
                coef$value <- var2[j + 1]
                coef_df <- rbind(coef_df, coef)
                if (hist == TRUE) {
                  if (is.na(var2_dt)) {
                    var2_dt <- eval(parse(text = paste0("m@frame$", var2)))
                  } else {
                    var2_dt <- var2_dt
                  }
                }
            } else {
                names(coef) <- c(var2, "coef", "ub", "lb")
                return(coef)
            }
        }
        coef_df$value <- as.factor(coef_df$value)
        interplot.plot(m = coef_df, steps = steps, hist = hist, var2_dt = var2_dt, point = point, 
            ercolor = ercolor, esize = esize, ralpha = ralpha, rfill = rfill, 
            ...) + facet_grid(. ~ value)
        
        
    } else {
        if(predPro == TRUE){
          
          if(is.null(var2_vals)) stop("The predicted probabilities cannot be estimated without defining 'var2_vals'.")
          
          df <- data.frame(m$model)
          df[[names(m@flist)]] <- NULL # omit L2 var
          if(sum(grep("X.weights.", names(df))) != 0) df <- select(df, -X.weights.) # removed the weights
          df_temp <- select(df, 1) # save the dependent variable separately
          df <- df[-1] %>% # get ride of the dv in case it's a factor
            map(function(var){
              if(is.factor(var)){
                model.matrix(~ var - 1)[, -1] %>% 
                  # get rid of the first (reference) group
                  as.data.frame()
              }else{
                as.numeric(var) # in case the initial one is a "labelled" class
              }
            })
          
          
          for(i in seq(df)){ 
            # use for loop to avoid the difficulty of flatting list containing vectors and matrices
            if(!is.data.frame(df[[i]])){
              # keep track the var names
              namesUpdate <- c(names(df_temp), names(df)[[i]])
              df_temp <- cbind(df_temp, df[[i]])
              names(df_temp) <- namesUpdate
            }else{
              df_temp <- cbind(df_temp, df[[i]])
            }
          }
          
          df <- df_temp
          
          names(df)[1] <- "(Intercept)" # replace DV with intercept
          df$`(Intercept)` <- 1
          
          if(var1 == var2){ # correct the name of squares
            names(df) <- sub("I\\.(.*)\\.2\\.", "I\\(\\1\\^2\\)", names(df))
          }
          
          iv_medians <- summarize_all(df, funs(median(., na.rm = TRUE))) 
          
          fake_data <- iv_medians[rep(1:nrow(iv_medians), each=steps*length(var2_vals)), ] 
          fake_data[[var1]] <- with(df, rep(seq(min(get(var1)), max(get(var1)), length.out=steps),
                                            steps=length(var2_vals)))
          fake_data[[var2]] <- rep(var2_vals, each=steps)
          fake_data[[var12]] <- fake_data[[var1]] * fake_data[[var2]]
          
          pp <- rowMeans(plogis(data.matrix(fake_data) %*% t(data.matrix(m.sims@fixef))))
          row_quantiles <- function (x, probs) {
            naValue <- NA
            storage.mode(naValue) <- storage.mode(x)
            nrow <- nrow(x)
            q <- matrix(naValue, nrow = nrow, ncol = length(probs))
            if (nrow > 0L) {
              t <- quantile(x[1L, ], probs = probs)
              colnames(q) <- names(t)
              q[1L, ] <- t
              if (nrow >= 2L) {
                for (rr in 2:nrow) {
                  q[rr, ] <- quantile(x[rr, ], probs = probs)
                }
              }
            }
            else {
              t <- quantile(0, probs = probs)
              colnames(q) <- names(t)
            }
            q <- drop(q)
            q
          }
          pp_bounds <- row_quantiles(plogis(data.matrix(fake_data) %*% t(data.matrix(m.sims@fixef))), prob = c((1 - ci)/2, 1 - (1 - ci)/2))
          pp <- cbind(pp, pp_bounds)
          pp <- pp*100
          colnames(pp) <- c("coef1", "lb", "ub")
          pp <- cbind(fake_data[, c(var1, var2)], pp)
          
          
          pp[,var2] <- as.factor(pp[,var2])
          
          names(pp)[1] <- "fake"
          names(pp)[2] <- "value"
          
          coef <- pp
          
        } else {
          ## Correct marginal effect for quadratic terms
          multiplier <- if (var1 == var2) 
              2 else 1
          
          for (i in 1:steps) {
              coef$coef1[i] <- mean(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                  multiplier * coef$fake[i] * m.sims@fixef[, match(var12, 
                    unlist(dimnames(m@pp$X)[2]))])
              coef$ub[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                  multiplier * coef$fake[i] * m.sims@fixef[, match(var12, 
                    unlist(dimnames(m@pp$X)[2]))], (1 - ci) / 2)
              coef$lb[i] <- quantile(m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
                  multiplier * coef$fake[i] * m.sims@fixef[, match(var12, 
                    unlist(dimnames(m@pp$X)[2]))], 1 - (1 - ci) / 2)
          }
        }
        
      multiplier <- if (var1 == var2) 
        2 else 1
      
      min_sim <- m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
        multiplier * xmin * m.sims@fixef[, match(var12, unlist(dimnames(m@pp$X)[2]))] # simulation of the value at the minimum value of the conditioning variable
      max_sim <- m.sims@fixef[, match(var1, unlist(dimnames(m@pp$X)[2]))] + 
        multiplier * xmax * m.sims@fixef[, match(var12, unlist(dimnames(m@pp$X)[2]))] # simulation of the value at the maximum value of the conditioning variable
      diff <- max_sim - min_sim # calculating the difference
      ci_diff <- c(
        quantile(diff, (1 - ci) / 2),
        quantile(diff, 1 - (1 - ci) / 2)
      ) # confidence intervals of the difference
      
        if (plot == TRUE) {
            if (hist == TRUE) {
                if (is.na(var2_dt)) {
                  var2_dt <- eval(parse(text = paste0("m@frame$", var2)))
                } else {
                  var2_dt <- var2_dt
                }
            }
            interplot.plot(m = coef, steps = steps, hist = hist, predPro = predPro, var2_vals = var2_vals, var2_dt = var2_dt, point = point, ercolor = ercolor, esize = esize, ralpha = ralpha, rfill = rfill, ci_diff = ci_diff, ...)
        } else {
            if(predPro == TRUE){
              names(coef) <- c(var2, paste0("values_in_", var1), "coef", "ub", "lb")
            } else {
              names(coef) <- c(var2, "coef", "ub", "lb")
            }
            
            return(coef)
        }
        
    }
}
