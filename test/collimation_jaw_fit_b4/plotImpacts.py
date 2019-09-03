import matplotlib.pyplot as plt
import numpy as np
import math

def fitProfile( x, fitParams, cLen ):
    '''
    fitParams[0]: const term
    fitParams[1]: linear term
    ...
    fitParams[-2]: n-th order term
    fitParams[-1]: scaling factor
    '''
    y=0.0
    for ii in range(len(fitParams)-1):
        if (ii==2):
            y+=(x**ii)*fitParams[ii]/cLen
        else:
            y+=(x**ii)*fitParams[ii]
    return y*fitParams[-1]

def rotateBy(xIn,yIn,skewAngle=0.0,direct=True):
    xOut=xIn*math.cos(skewAngle)+math.sin(skewAngle)*yIn
    yOut=yIn*math.cos(skewAngle)-math.sin(skewAngle)*xIn
    return xOut,yOut
    
def parseFirstImpacts(iFileName='FirstImpacts.dat'):
    print 'parsing file %s ...'%(iFileName)
    data=[]
    with open(iFileName,'r') as iFile:
        for line in iFile.readlines():
            if (line.startswith('#')): continue
            data.append([])
            tmpData=line.strip().split()
            for ii,tmpDatum in zip(range(len(tmpData)),tmpData):
                data[-1].append(float(tmpDatum))
                if ( ii<=3 ):
                    data[-1][-1]=int(data[-1][-1])
    print '...done - read %i lines.'%(len(data))
    return data

def parseFlukaImpacts(iFileName='FLUKA_impacts_all.dat'):
    print 'parsing file %s ...'%(iFileName)
    data=[]
    with open(iFileName,'r') as iFile:
        for line in iFile.readlines():
            if (line.startswith('#')): continue
            data.append([])
            tmpData=line.strip().split()
            for ii,tmpDatum in zip(range(len(tmpData)),tmpData):
                data[-1].append(float(tmpDatum))
                if ( ii==0 or ii>=7 ):
                    data[-1][-1]=int(data[-1][-1])
    print '...done - read %i lines.'%(len(data))
    return data

def parseJawProfiles(iFileName='JawProfiles.dat'):
    print 'parsing file %s ...'%(iFileName)
    data=[]
    with open(iFileName,'r') as iFile:
        for line in iFile.readlines():
            if (line.startswith('#')): continue
            data.append([])
            tmpData=line.strip().split()
            for ii,tmpDatum in zip(range(len(tmpData)),tmpData):
                data[-1].append(float(tmpDatum))
                if ( ii<=2 ):
                    data[-1][-1]=int(data[-1][-1])
    print '...done - read %i lines.'%(len(data))
    return data

def getFittingData(iFileName='fort.6'):
    print 'parsing file %s ...'%(iFileName)
    profiles=[ [], [], [] ]
    with open(iFileName,'r') as iFile:
        for line in iFile.readlines():
            line=line.strip()
            if (line.startswith('Fit point #')):
                data=line.split()
                profiles[0].append(float(data[4]))
                profiles[1].append(float(data[5])*1000)
                profiles[2].append(float(data[6])*1000)
    return profiles

def parseCollGaps(iFileName='collgaps.dat'):
    print 'parsing file %s ...'%(iFileName)
    collData=[]
    with open(iFileName,'r') as iFile:
        for line in iFile.readlines():
            line=line.strip()
            if (line.startswith('#')): continue
            data=line.split()
            for ii in range(len(data)):
                if ( ii!=1 and ii !=6):
                    data[ii]=float(data[ii])
                    if ( ii==0 ):
                        data[ii]=int(data[ii]+1E-4)
            collData.append(data[:])
    print ' ...acquired %i collimators'%(len(collData))
    return collData

def plotFirstImpacts(iCols,lCols,fitProfileS,fitProfileY1,fitProfileY2,sixCurve,data):
    plt.figure('First impacts',figsize=(16,16))
    iPlot=0
    for iCol,lCol,jCol in zip(iCols,lCols,range(len(lCols))):
        Ss_in=[] ; Ss_out=[]
        Hs_in=[] ; Hs_out=[]
        Vs_in=[] ; Vs_out=[]
        for datum in data:
            if (datum[2]==iCol):
                # - s_in: entrance at jaw/slice or actual impact point;
                # - x_in,xp_in,y_in,yp_in (jaw ref sys): particle at front face of
                #   collimator/slice, not at impact on jaw
                # - x_out,xp_out,y_out,yp_out (jaw ref sys): particle exit point at
                #   collimator/slice, or coordinate of hard interaction
                ss=datum[4]
                xx=datum[6]
                yy=datum[8]
                Ss_in.append(ss)
                Hs_in.append(xx*1000)
                Vs_in.append(yy*1000)
                ss=datum[5]
                xx=datum[10]
                yy=datum[12]
                Ss_out.append(ss)
                Hs_out.append(xx*1000)
                Vs_out.append(yy*1000)
        
        iPlot+=1
        plt.subplot(len(iCols),3,iPlot)
        if ( iCol==9 ):
            plt.plot(sixCurve[0],sixCurve[1],'ko-',label='6T fit')
            plt.plot(sixCurve[0],sixCurve[2],'ko-')
        plt.plot(fitProfileS[jCol],fitProfileY1[jCol],'g-',label='expected')
        plt.plot(fitProfileS[jCol],fitProfileY2[jCol],'g-')
        plt.plot(Ss_in,Hs_in,'ro',label='in')
        plt.plot(Ss_out,Hs_out,'bo',label='out')
        plt.xlabel(r's_{jaw} [m]')
        plt.ylabel(r'x_{jaw} [mm]')
        plt.title('iColl=%i - Cleaning plane'%(iCol))
        plt.legend(loc='best',fontsize=10)
        plt.tight_layout()
        plt.grid()

        iPlot+=1
        plt.subplot(len(iCols),3,iPlot)
        plt.plot(Ss_in,Vs_in,'ro',label='in')
        plt.plot(Ss_out,Vs_out,'bo',label='out')
        plt.xlabel(r's_{jaw} [m]')
        plt.ylabel(r'y_{jaw} [mm]')
        plt.title('iColl=%i - Ortoghonal plane'%(iCol))
        plt.legend(loc='best',fontsize=10)
        plt.tight_layout()
        plt.grid()

        iPlot+=1
        plt.subplot(len(iCols),3,iPlot)
        plt.plot(Hs_in,Vs_in,'ro',label='in')
        plt.plot(Hs_out,Vs_out,'bo',label='out')
        plt.xlabel(r'x_{jaw} [mm]')
        plt.ylabel(r'y_{jaw} [mm]')
        plt.title('iColl=%i - transverse plane'%(iCol))
        plt.legend(loc='best',fontsize=10)
        plt.tight_layout()
        plt.grid()

    plt.show()

def plotFlukaImpacts(iCols,lCols,fitProfileS,fitProfileY1,fitProfileY2,sixCurve,data,skewAngles):
    plt.figure('FLUKA impacts all',figsize=(16,16))
    iPlot=0
    for iCol,lCol,jCol,skewAngle in zip(iCols,lCols,range(len(lCols)),skewAngles):
        Ss=[]
        Hs=[]
        Vs=[]
        for datum in data:
            if (datum[0]==iCol):
                ss=datum[2]
                xx=datum[3]
                yy=datum[5]
                xx,yy=rotateBy(xx,yy,skewAngle=skewAngle)
                Ss.append(ss)
                Hs.append(xx)
                Vs.append(yy)
        
        iPlot+=1
        plt.subplot(len(iCols),3,iPlot)
        if ( iCol==9 ):
            plt.plot(sixCurve[0],sixCurve[1],'ko-',label='6T fit')
            plt.plot(sixCurve[0],sixCurve[2],'ko-')
        plt.plot(fitProfileS[jCol],fitProfileY1[jCol],'g-',label='expected')
        plt.plot(fitProfileS[jCol],fitProfileY2[jCol],'g-')
        plt.plot(Ss,Hs,'ro',label='impact')
        plt.xlabel(r's_{jaw} [m]')
        plt.ylabel(r'x_{jaw} [mm]')
        plt.title('iColl=%i - Cleaning plane'%(iCol))
        plt.legend(loc='best',fontsize=10)
        plt.tight_layout()
        plt.grid()

        iPlot+=1
        plt.subplot(len(iCols),3,iPlot)
        plt.plot(Ss,Vs,'ro',label='impact')
        plt.xlabel(r's_{jaw} [m]')
        plt.ylabel(r'y_{jaw} [mm]')
        plt.title('iColl=%i - Ortoghonal plane'%(iCol))
        plt.legend(loc='best',fontsize=10)
        plt.tight_layout()
        plt.grid()

        iPlot+=1
        plt.subplot(len(iCols),3,iPlot)
        plt.plot(Hs,Vs,'ro',label='impact')
        plt.xlabel(r'x_{jaw} [mm]')
        plt.ylabel(r'y_{jaw} [mm]')
        plt.title('iColl=%i - transverse plane'%(iCol))
        plt.legend(loc='best',fontsize=10)
        plt.tight_layout()
        plt.grid()

    plt.show()

def plotJawProfiles(iCols,lCols,fitProfileS,fitProfileY1,fitProfileY2,sixCurve,data):
    plt.figure('Jaw Profiles',figsize=(16,16))
    iPlot=0
    for iCol,lCol,jCol in zip(iCols,lCols,range(len(lCols))):
        Ss_in=[] ; Ss_out=[]
        Hs_in=[] ; Hs_out=[]
        Vs_in=[] ; Vs_out=[]
        for datum in data:
            if (datum[0]==iCol):
                ss=datum[7]
                xx=datum[3]
                yy=datum[5]
                if ( datum[-1]==1 ):
                    # entrance
                    Ss_in.append(ss)
                    Hs_in.append(xx*1000)
                    Vs_in.append(yy*1000)
                else:
                    # exit
                    Ss_out.append(ss)
                    Hs_out.append(xx*1000)
                    Vs_out.append(yy*1000)
        
        iPlot+=1
        plt.subplot(len(iCols),3,iPlot)
        if ( iCol==9 ):
            plt.plot(sixCurve[0],sixCurve[1],'ko-',label='6T fit')
            plt.plot(sixCurve[0],sixCurve[2],'ko-')
        plt.plot(fitProfileS[jCol],fitProfileY1[jCol],'g-',label='expected')
        plt.plot(fitProfileS[jCol],fitProfileY2[jCol],'g-')
        plt.plot(Ss_in,Hs_in,'ro',label='in')
        plt.plot(Ss_out,Hs_out,'bo',label='out')
        plt.xlabel(r's_{jaw} [m]')
        plt.ylabel(r'x_{jaw} [mm]')
        plt.title('iColl=%i - Cleaning plane'%(iCol))
        plt.legend(loc='best',fontsize=10)
        plt.tight_layout()
        plt.grid()

        iPlot+=1
        plt.subplot(len(iCols),3,iPlot)
        plt.plot(Ss_in,Vs_in,'ro',label='in')
        plt.plot(Ss_out,Vs_out,'bo',label='out')
        plt.xlabel(r's_{jaw} [m]')
        plt.ylabel(r'y_{jaw} [mm]')
        plt.title('iColl=%i - Ortoghonal plane'%(iCol))
        plt.legend(loc='best',fontsize=10)
        plt.tight_layout()
        plt.grid()

        iPlot+=1
        plt.subplot(len(iCols),3,iPlot)
        plt.plot(Hs_in,Vs_in,'ro',label='in')
        plt.plot(Hs_out,Vs_out,'bo',label='out')
        plt.xlabel(r'x_{jaw} [mm]')
        plt.ylabel(r'y_{jaw} [mm]')
        plt.title('iColl=%i - transverse plane'%(iCol))
        plt.legend(loc='best',fontsize=10)
        plt.tight_layout()
        plt.grid()

    plt.show()

if ( __name__ == "__main__" ):
    iCols=[9,10,11]
    fitParams=[
        # iCol=9
        [   2.70E-3, -0.18,  0.18,  0.0, 0.0, 0.0, 2 ], 
        [ 5.1962E-4,  0.09, -0.27, 50.0, 0.0, 0.0, 2 ],
        # iCol=10
        [ 0., 1. ],
        [ 0., 1. ],
        # iCol=11
        [ 0., 1. ],
        [ 0., 1. ]
    ]
    nPoints=50
    
    collData=parseCollGaps()
    lCols=[] ; hGaps=[] ; skewAngles=[]
    for iCol in iCols:
        for collDatum in collData:
            if ( collDatum[0]==iCol ):
                lCols.append(collDatum[7])
                hGaps.append(collDatum[5])
                skewAngles.append(collDatum[2])
                break
            
    fitProfileS=[] ; fitProfileY1=[] ; fitProfileY2=[]
    for lCol,hGap,jCol in zip(lCols,hGaps,range(len(iCols))):
        Ss=[ float(ii)/nPoints*lCol for ii in range(nPoints+1) ]
        Y1s=[  (fitProfile(s,fitParams[  2*jCol],lCol)+hGap)*1000 for s in Ss ]
        Y2s=[ -(fitProfile(s,fitParams[1+2*jCol],lCol)+hGap)*1000 for s in Ss ]
        fitProfileS.append(Ss[:])
        fitProfileY1.append(Y1s[:])
        fitProfileY2.append(Y2s[:])

    sixCurve=getFittingData()
    
    data=parseFirstImpacts()
    plotFirstImpacts(iCols,lCols,fitProfileS,fitProfileY1,fitProfileY2,sixCurve,data)
    data=parseFlukaImpacts()
    plotFlukaImpacts(iCols,lCols,fitProfileS,fitProfileY1,fitProfileY2,sixCurve,data,skewAngles)
    data=parseJawProfiles()
    plotJawProfiles(iCols,lCols,fitProfileS,fitProfileY1,fitProfileY2,sixCurve,data)
