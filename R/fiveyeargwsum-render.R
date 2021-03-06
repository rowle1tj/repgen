createfiveyeargwsumPlot <- function(reportObject){
  #Rendering Options
  options(scipen=8)
  
  #Validation Options
  requiredTimeSeriesFields <- c(
    "points",
    "approvals",
    "qualifiers",
    "startTime",
    "endTime",
    "isVolumetricFlow",
    "unit",
    "grades",
    "type",
    "gaps",
    "gapTolerances",
    "name"
  )
  requiredMetadataFields <- c(
    'startDate',
    'endDate',
    'isInverted',
    'timezone',
    'stationId',
    'title'
  )

  #Validate Report Metadata
  metaData <- fetchReportMetadata(reportObject)

  #Get Necessary Report Metadata
  if(validateFetchedData(metaData, "metadata", requiredMetadataFields)){
    timezone <- fetchReportMetadataField(reportObject, 'timezone')
    excludeMinMaxFlag <- parseReportMetadataField(reportObject, 'excludeMinMax', FALSE)
    invertedFlag <- parseReportMetadataField(reportObject, 'isInverted', FALSE)
    startDate <- toStartOfMonth(flexibleTimeParse(fetchReportMetadataField(reportObject, 'startDate'), timezone=timezone))
    endDate <- toEndOfMonth(flexibleTimeParse(fetchReportMetadataField(reportObject, 'endDate'), timezone=timezone))
    date_seq_mo <- seq(from=startDate, to=endDate, by="month")
    first_yr <- date_seq_mo[which(month(date_seq_mo) == 1)[1]]
    date_seq_yr <- seq(from=first_yr, to=endDate, by="year")
    month_label_location <- date_seq_mo + (60*60*24*14) #make at 15th of month
    month_label_split <- strsplit(as.character(month(date_seq_mo, label=TRUE)), "")
    month_label <- unlist(lapply(month_label_split, function(x) {x[1]}))
  }

  #before we assign timeseries details below, check to see if we have empty firstStatDerived timeseries and resort them so we do not have an empty slot there
  #if we don't, set prefixes, otherwise legend prefixes are set in resortTimeSeries function
  if(isEmptyOrBlank(reportObject[['firstStatDerived']])) {
    reportObject <- resortTimeSeries(reportObject)
  } else {
    reportObject[['reportMetadata']][['firstStatDerivedOriginalPrefix']] <- "Stat 1: "
    reportObject[['reportMetadata']][['secondStatDerivedOriginalPrefix']] <- "Stat 2: "
    reportObject[['reportMetadata']][['thirdStatDerivedOriginalPrefix']] <- "Stat 3: "
    reportObject[['reportMetadata']][['fourthStatDerivedOriginalPrefix']] <- "Stat 4: "
  }
  
  #Get Basic Plot data
  stat1TimeSeries <- parseTimeSeries(reportObject, 'firstStatDerived', 'firstStatDerivedLabel', timezone, isDV=TRUE)
  stat2TimeSeries <- parseTimeSeries(reportObject, 'secondStatDerived', 'secondStatDerivedLabel', timezone, isDV=TRUE)
  stat3TimeSeries <- parseTimeSeries(reportObject, 'thirdStatDerived', 'thirdStatDerivedLabel', timezone, isDV=TRUE)
  stat4TimeSeries <- parseTimeSeries(reportObject, 'fourthStatDerived', 'fourthStatDerivedLabel', timezone, isDV=TRUE)

  #Validate Basic Plot Data
  if(all(isEmptyOrBlank(c(stat1TimeSeries, stat2TimeSeries, stat3TimeSeries, stat4TimeSeries)))){
    return(NULL)
  }
  
  #Find the highest priority TS that has data
  priorityTS <- list(stat1TimeSeries, stat2TimeSeries, stat3TimeSeries, stat4TimeSeries)
  priorityTS <- priorityTS[unlist(lapply(priorityTS, function(ts){!isEmptyOrBlank(ts)}))][[1]]
  #get sides and lims for all time series
  sides <- getSides(stat1TimeSeries, stat2TimeSeries, stat3TimeSeries, stat4TimeSeries)
  
  #Get Additional Plot Data
  groundWaterLevels <- parseGroundWaterLevels(reportObject)
  minMaxIVs <- parseMinMaxIVs(reportObject, timezone, priorityTS[['type']], invertedFlag, excludeMinMaxFlag, FALSE)
  minMaxLabels <- NULL
  minMaxEst <- list()
  minMaxCanLog <- TRUE

  if(!isEmptyOrBlank(minMaxIVs)){
    primarySeriesQualifiers <- parsePrimarySeriesQualifiers(reportObject, filterCode = 'E')
    minMaxEst[['max_iv']] <- any((minMaxIVs$max_iv$time >= primarySeriesQualifiers$startTime) & (minMaxIVs$max_iv$time <= primarySeriesQualifiers$endTime))
    minMaxEst[['min_iv']] <- any((minMaxIVs$min_iv$time >= primarySeriesQualifiers$startTime) & (minMaxIVs$min_iv$time <= primarySeriesQualifiers$endTime))
    minMaxLabels <- minMaxIVs[grepl("label", names(minMaxIVs))]
    minMaxPoints <- minMaxIVs[!grepl("label", names(minMaxIVs))]
    minMaxCanLog <- minMaxIVs[['canLog']]
  }
  
  primarySeriesApprovals <- parsePrimarySeriesApprovals(reportObject, startDate, endDate)
  primarySeriesLegend <- fetchReportMetadataField(reportObject, 'primarySeriesLabel')
  approvals <- readApprovalBar(primarySeriesApprovals, timezone, legend_nm=primarySeriesLegend, snapToDayBoundaries=TRUE)
  logAxis <- isLogged(priorityTS[['points']], priorityTS[['isVolumetricFlow']], FALSE) && minMaxCanLog

  #Create the Base Plot Object
  plot_object <- gsplot(yaxs = 'i', xaxt = "n", mar = c(8,4,4,12) + 0.1) %>%
      axis(side = 1, at = date_seq_mo, labels = FALSE) %>%
      view(xlim = c(startDate, endDate), log=ifelse(logAxis, 'y', '')) %>%
      axis(side = 2, reverse = invertedFlag, las = 0) %>%
      grid(col = "lightgrey", lty = 1)

  plot_object <- 
    XAxisLabels(plot_object, month_label, month_label_location, date_seq_yr + months(6))
 
  #Plot the primary Time Series on left axis
  if(!isEmptyOrBlank(stat1TimeSeries)) {
    plot_object <- plotTimeSeries(plot_object, stat1TimeSeries, 'stat1TimeSeries', timezone, getFiveYearPlotConfig, list(prefix=reportObject[['reportMetadata']][['firstStatDerivedOriginalPrefix']], label=stat1TimeSeries[['type']], ylim=sides[['typeLims']][[stat1TimeSeries[['type']]]][['ylim']], side=as.numeric(sides[['seriesList']][['stat1TimeSeries']][['side']])), isDV=TRUE)
  }

  #plot secondary time series 
  if(!isEmptyOrBlank(stat2TimeSeries)) {
    plot_object <- plotTimeSeries(plot_object, stat2TimeSeries, 'stat2TimeSeries', timezone, getFiveYearPlotConfig, list(prefix=reportObject[["reportMetadata"]][["secondStatDerivedOriginalPrefix"]], label=paste0(stat2TimeSeries[['type']], ", ", stat2TimeSeries[['unit']]), ylim=sides[['typeLims']][[stat2TimeSeries[['type']]]][['ylim']], side=as.numeric(sides[['seriesList']][['stat2TimeSeries']][['side']])), isDV=TRUE)
  }
  
  #plot tertiary time series
  if(!isEmptyOrBlank(stat3TimeSeries)) {
    plot_object <- plotTimeSeries(plot_object, stat3TimeSeries, 'stat3TimeSeries', timezone, getFiveYearPlotConfig, list(prefix=reportObject[['reportMetadata']][['thirdStatDerivedOriginalPrefix']], label=paste0(stat3TimeSeries[['type']], ", ", stat3TimeSeries[['unit']]), ylim=sides[['typeLims']][[stat3TimeSeries[['type']]]][['ylim']], side=as.numeric(sides[['seriesList']][['stat3TimeSeries']][['side']]), independentAxes=sides[['seriesList']][['stat3TimeSeries']][['side']]==6, isDV=TRUE))
  }
  
  #plot quaternary time series
  if(!isEmptyOrBlank(stat4TimeSeries)) {
    plot_object <- plotTimeSeries(plot_object, stat4TimeSeries, 'stat4TimeSeries', timezone, getFiveYearPlotConfig, list(prefix=reportObject[['reportMetadata']][['fourthStatDerivedOriginalPrefix']], label=paste0(stat4TimeSeries[['type']], ", ", stat4TimeSeries[['unit']]), ylim=sides[['typeLims']][[stat4TimeSeries[['type']]]][['ylim']], side=as.numeric(sides[['seriesList']][['stat4TimeSeries']][['side']]), independentAxes=sides[['seriesList']][['stat4TimeSeries']][['side']]==8, isDV=TRUE))
  }

  #Plot Other Items
  plot_object <- plotItem(plot_object, groundWaterLevels, getFiveYearPlotConfig, list(groundWaterLevels, 'gw_level'), isDV=TRUE)
  plot_object <- plotItem(plot_object, minMaxPoints[['min_iv']], getFiveYearPlotConfig, list(minMaxPoints[['min_iv']], 'min_iv', minMaxEst=minMaxEst[['min_iv']]), isDV=TRUE)
  plot_object <- plotItem(plot_object, minMaxPoints[['max_iv']], getFiveYearPlotConfig, list(minMaxPoints[['max_iv']], 'max_iv', minMaxEst=minMaxEst[['max_iv']]), isDV=TRUE)

  # add vertical lines to delineate calendar year boundaries
  plot_object <- DelineateYearBoundaries(plot_object, date_seq_yr)

  # add approval bars
  plot_object <- addToGsplot(plot_object, getApprovalBarConfig(approvals, ylim(plot_object, side = 2), logAxis))

  plot_object <- rmDuplicateLegendItems(plot_object)

  # Add space to the top of the Y Axis
  plot_object <- RescaleYTop(plot_object)

  #Add invalid GW level note
  if(!isEmptyOrBlank(fetchReportMetadataField(reportObject, 'gwlevelAllValid')) && fetchReportMetadataField(reportObject, 'gwlevelAllValid') == FALSE){
    plot_object <- mtext(plot_object, text = "Note: Water levels with improper date/time formats not plotted.", side=3, cex=0.6, line=0.75, adj=1, axes=FALSE)
  }

  #Add approval explanation label to the top of the plot
  plot_object <- mtext(plot_object, text = "Displayed approval level(s) are from the source TS that statistics are derived from.", side=3, cex=0.6, line=0.1, adj=1, axes=FALSE)

  #Add Min/Max labels if we aren't plotting min and max
  formattedLabels <- lapply(minMaxLabels, function(l) {formatMinMaxLabel(l, priorityTS[['unit']])})
  plot_object <- plotItem(plot_object, formattedLabels[['min_iv_label']], getFiveYearPlotConfig, list(formattedLabels[['min_iv_label']], 'min_iv_label'), isDV=TRUE)
  plot_object <- plotItem(plot_object, formattedLabels[['max_iv_label']], getFiveYearPlotConfig, list(formattedLabels[['max_iv_label']], 'max_iv_label', ylabel="", lineOffset=length(minMaxLabels)), isDV=TRUE)
  
  plot_object <- plotFiveYearLegend(plot_object, startDate, endDate, timezone, 0.1)
  return(plot_object)
}

getFiveYearPlotConfig <- function(plotItem, plotItemName, prefix, label, side, independentAxes=TRUE, minMaxEst=FALSE, lineOffset=1, ...) {
  styles <- getFiveyearStyle()
  
  if(length(plotItem) > 1 || (!is.null(nrow(plotItem)) && nrow(plotItem) > 1)){
    x <- plotItem[['time']]
    y <- plotItem[['value']]
    legend.name <- nullMask(plotItem[['legend.name']])
  }

  indAxes <- TRUE
  indAnnotations <- TRUE
  
  if(independentAxes){
    indAxes <- FALSE
    indAnnotations <- FALSE
  }
  
  args <- list(...)
  
  styles <- switch(plotItemName, 
      stat1TimeSeries = list(
        lines = append(list(x=x, y=y, side=side, ylab=label, legend.name=paste(prefix, legend.name)), styles$stat1_lines),
        view = list(side=side)
      ),
      stat2TimeSeries = list(
        lines = append(list(x=x, y=y, side=side, ylab=label, legend.name=paste(prefix, legend.name)), styles$stat2_lines),
        view = list(side=side)
      ),
      stat3TimeSeries = list(
        lines = append(list(x=x, y=y, side=side, axes=indAxes, ylab=label, ann=indAnnotations, legend.name=paste(prefix, legend.name)), styles$stat3_lines),
        view = list(side=side)
      ),
      stat4TimeSeries = list(
        lines = append(list(x=x, y=y, side=side, axes=indAxes, ylab=label, ann=indAnnotations, legend.name=paste(prefix, legend.name)), styles$stat4_lines),
        view = list(side=side)
      ),
      max_iv = list(
        points = append(list(x=x, y=y, legend.name=ifelse(minMaxEst, paste("(Estimated)", legend.name), legend.name), col=ifelse(minMaxEst, "red", "blue")), styles$max_iv_points)
      ),
      min_iv = list(
        points = append(list(x=x, y=y, legend.name=ifelse(minMaxEst, paste("(Estimated)", legend.name), legend.name), col=ifelse(minMaxEst, "red", "blue")), styles$min_iv_points)
      ),
      min_iv_label = list(
          mtext = append(list(ifelse(minMaxEst, paste("(Estimated)", plotItem), plotItem)), styles$bottom_iv_label)
      ),
      max_iv_label = list(
          mtext = append(list(ifelse(minMaxEst, paste("(Estimated)", plotItem), plotItem)), if(lineOffset > 1) styles$top_iv_label else styles$bottom_iv_label)
      ),
      gw_level = list(
          points = append(list(x=x,y=y), styles$gw_level_points)
      )
  )
  
  return(styles)
}

#' Sort data and sides
#' @description Depending on the configuration, stat-derived time series will be plotted on different sides. This function compares types and figures out where to plot the data and what lims they will need to use to construct each side.
#' @param stat1TimeSeries the stat-derived time series 1 selected
#' @param stat2TimeSeries the stat-derived time series 2 selected
#' @param stat3TimeSeries the stat-derived time series 3 selected
#' @param stat4TimeSeries the stat-derived time series 4 selected
#' @return named list with three items, a list of sides, list of series, and list of lims.)
#' 
getSides <- function(stat1TimeSeries, stat2TimeSeries, stat3TimeSeries, stat4TimeSeries) {
  ylimPrimaryData <- data.frame(time=c(), value=c())
  ylimSecondaryData <- data.frame(time=c(), value=c())
  ylimTertiaryData <- data.frame(time=c(), value=c())
  ylimQuaternaryData <- data.frame(time=c(), value=c())
  
  types <- data.frame( "timeseries" = character(), "types" = character(), "lims" = character(), stringsAsFactors = FALSE)

  if(!isEmptyOrBlank(stat1TimeSeries)) {
    ylimPrimaryData <- data.frame(stat1TimeSeries[['points']][['time']],stat1TimeSeries[['points']][['value']])
    colnames(ylimPrimaryData) <- c("time", "value")
    types[1,] <- c("stat1TimeSeries",stat1TimeSeries[['type']],"ylimPrimaryData")
  } else {
    types[1,] <- c("stat1TimeSeries","","")
  }
  
  if(!isEmptyOrBlank(stat2TimeSeries)) {
    ylimSecondaryData <- data.frame(stat2TimeSeries[['points']][['time']], stat2TimeSeries[['points']][['value']])
    colnames(ylimSecondaryData) <- c("time", "value")
    types[2,] <- c("stat2TimeSeries",stat2TimeSeries[['type']],"ylimSecondaryData")
  } else {
    types[2,] <- c("stat2TimeSeries","","")
  }
  
  if(!isEmptyOrBlank(stat3TimeSeries)) {
    ylimTertiaryData <- data.frame(stat3TimeSeries[['points']][['time']], stat3TimeSeries[['points']][['value']])
    colnames(ylimTertiaryData) <- c("time", "value")
    types[3,] <- c("stat3TimeSeries",stat3TimeSeries[['type']],"ylimTertiaryData")
  } else {
    types[3,] <- c("stat3TimeSeries","","")
  }
  
  if(!isEmptyOrBlank(stat4TimeSeries)) {
    ylimQuaternaryData <- data.frame(stat4TimeSeries[['points']][['time']], stat4TimeSeries[['points']][['value']])
    colnames(ylimQuaternaryData) <- c("time", "value")
    types[4,] <- c("stat4TimeSeries",stat4TimeSeries[['type']],"ylimQuaternaryData")
  } else {
    types[4,] <- c("stat4TimeSeries","","")
  }
  
  #unique types
  uniqueTypes <- data.frame(types=unique(c(stat1TimeSeries[['type']],stat2TimeSeries[['type']],stat3TimeSeries[['type']],stat4TimeSeries[['type']])), stringsAsFactors = FALSE)
  uniqueTypes$side <- ""
  
  #possible sides/axes
  sides <- c(2, 4, 6, 8)

  #assign uniqueTypes a side
  for(i in 1:nrow(uniqueTypes)) {
    uniqueTypes[i,2] <- sides[i]
  }
  
  #merge uniqueTypes and types to get list of timeseries, type and side
  sides <- merge(uniqueTypes, types)
  
  #reformat data by side and series
  sideList <- split(sides, as.factor(sides[['side']]))
  seriesList <- split(sides, as.factor(sides[['timeseries']]))
  
  #Get min/max ylims for each side, organized by timeseries type
  limsList <- list(ylimPrimaryData=ylimPrimaryData, ylimSecondaryData=ylimSecondaryData, ylimTertiaryData=ylimTertiaryData, ylimQuaternaryData=ylimQuaternaryData)
  typeLims <- list()
  
  for(i in 1:length(sideList)) {
    lims <- data.frame(time=c(), value=c())
    limsToInclude <- sideList[[i]][['lims']]
    for (j in 1:length(limsToInclude)) {
      lims <- rbind(lims, limsList[[limsToInclude[j]]])
    }
    ymax <- max(lims$value)
    ymin <- min(lims$value)
    xmax <- max(lims$time)
    xmin <- min(lims$time)
    ylim = c(ymin, ymax)
    xlim = c(xmin, xmax)
    typeLims[[unique(sideList[[i]][["types"]])]] <- list(ylim=ylim, xlim=xlim)
  }
  

  return(list(sideList=sideList, seriesList=seriesList, typeLims=typeLims))

}

#' Plot Five Year GW Legend
#'
#' @description Given the plot object and additional necessary parameters, calculates the
#' legend offset and then adds the legend to the plot.
#' @param plot_object The gsplot object to add the legend to
#' @param startDate The start date of the report
#' @param endDate The end date of the report
#' @param timezone The timezone of the report
#' @param initialOffset The initial amount to offset the legend by
#' @param modOffset [Default: 1] An optional amount to multiply the final calculated offset by
#' @return gsplot object with legend added
plotFiveYearLegend <- function(plot_object, startDate, endDate, timezone, initialOffset, modOffset=1){
  legend_items <- plot_object$legend$legend.auto$legend
  ncol <- ifelse(length(legend_items) > 3, 2, 1)
  
  #Legend offset needs to be calculated based on the number of lines and columns to be consistent in position
  leg_lines <- ifelse(ncol==2, ceiling((length(legend_items) - 6)/2), length(legend_items))
  legend_offset <- ifelse(ncol==2, initialOffset+(0.025*leg_lines), initialOffset/2+(0.025*leg_lines))
  legend_offset <- legend_offset * modOffset
  legend_offset <- legend_offset+.2
  
  #Add Legend to the plot
  plot_object <- legend(plot_object, location="below", cex=0.8, legend_offset=legend_offset, y.intersp=1.5, ncol=ncol)
  
  return(plot_object)
}

#' Resort Time Series
#' @description Before we start assigning time series and rendering plot components, resort the timeseries so we don't have any empty firstStatDerived slots
#' otherwise the min/max and approval bars dont draw correctly. 
#' Also, assign the prefixes from the original data so the user doesn't know we're shuffling things around behind the scenes
#' @param reportObject the JSON to inspect and reassign/re-order time series
#' @return reportObject with reassigned time series
resortTimeSeries <- function(reportObject) {
  #if max time series is selected only, then rejigger the reportObject so that it's the firstStatDerived instead of secondStatDerived
  if(!isEmptyOrBlank(reportObject[['secondStatDerived']]) && isEmptyOrBlank(reportObject[['firstStatDerived']])) {
    reportObject[['firstStatDerived']] <- reportObject[['secondStatDerived']]
    reportObject[['secondStatDerived']] <- ""
    reportObject[['reportMetadata']][['firstStatDerived']] <- reportObject[['reportMetadata']][['secondStatDerived']]
    reportObject[['reportMetadata']][['secondStatDerived']] <- ""
    reportObject[['reportMetadata']][['firstStatDerivedLabel']] <- reportObject[['reportMetadata']][['secondStatDerivedLabel']]
    reportObject[['reportMetadata']][['secondStatDerivedLabel']] <- ""
    reportObject[['reportMetadata']][['firstStatDerivedOriginalPrefix']] <- "Stat 2: "
  }
  
  #if min time series is selected only, then rejigger the reportObject so that it's the firstStatDerived instead of thirdStatDerived
  if(!isEmptyOrBlank(reportObject[['thirdStatDerived']]) && isEmptyOrBlank(reportObject[['firstStatDerived']])) {
    reportObject[['firstStatDerived']] <- reportObject[['thirdStatDerived']]
    reportObject[['thirdStatDerived']] <- ""
    reportObject[['reportMetadata']][['firstStatDerived']] <- reportObject[['reportMetadata']][['thirdStatDerived']]
    reportObject[['reportMetadata']][['thirdStatDerived']] <- ""
    reportObject[['reportMetadata']][['firstStatDerivedLabel']] <- reportObject[['reportMetadata']][['thirdStatDerivedLabel']]
    reportObject[['reportMetadata']][['thirdStatDerivedLabel']] <- ""
    reportObject[['reportMetadata']][['firstStatDerivedOriginalPrefix']] <- "Stat 3: "
  }
  
  #if fourtn stat derived time series is selected only, then rejigger the reportObject so that it's the firstStatDerived instead of fourthStatDerived
  if(!isEmptyOrBlank(reportObject[['fourthStatDerived']]) && isEmptyOrBlank(reportObject[['firstStatDerived']])) {
    reportObject[['firstStatDerived']] <- reportObject[['fourthStatDerived']]
    reportObject[['fourthStatDerived']] <- ""
    reportObject[['reportMetadata']][['firstStatDerived']] <- reportObject[['reportMetadata']][['fourthStatDerived']]
    reportObject[['reportMetadata']][['fourthStatDerived']] <- ""
    reportObject[['reportMetadata']][['firstStatDerivedLabel']] <- reportObject[['reportMetadata']][['fourthStatDerivedLabel']]
    reportObject[['reportMetadata']][['fourthStatDerivedLabel']] <- ""
    reportObject[['reportMetadata']][['firstStatDerivedOriginalPrefix']] <- "Stat 4: "
  }
  
  return(reportObject=reportObject) 
}