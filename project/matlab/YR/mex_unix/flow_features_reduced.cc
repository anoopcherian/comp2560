#include <math.h>
#include "mex.h"

// small value, used to avoid division by zero
#define eps 0.0001

// unit vectors used to compute gradient orientation
double uu[9] = {1.0000, 
		0.9397, 
		0.7660, 
		0.500, 
		0.1736, 
		-0.1736, 
		-0.5000, 
		-0.7660, 
		-0.9397};
double vv[9] = {0.0000, 
		0.3420, 
		0.6428, 
		0.8660, 
		0.9848, 
		0.9848, 
		0.8660, 
		0.6428, 
		0.3420};

static inline double min(double x, double y) { return (x <= y ? x : y); }
static inline double max(double x, double y) { return (x <= y ? y : x); }

static inline int min(int x, int y) { return (x <= y ? x : y); }
static inline int max(int x, int y) { return (x <= y ? y : x); }

// main function:
// takes a flow image: fim(:,:,2), where u=fim(:,:,1) and v=fim(:,:,2).
// and bin size 
// returns HOG features

mxArray *process(const mxArray *mxfimage, const mxArray *mxsbin) {
  double *fim = (double *)mxGetPr(mxfimage);
  const int *dims = mxGetDimensions(mxfimage);
  if (mxGetNumberOfDimensions(mxfimage) != 3 ||
      dims[2] == 1 ||  // we may have either dims[2]=2 or 3 (padded).
      mxGetClassID(mxfimage) != mxDOUBLE_CLASS)
    mexErrMsgTxt("Invalid input");

  int sbin = (int)mxGetScalar(mxsbin);

  // memory for caching orientation histograms & their norms
  int blocks[2];
  blocks[0] = (int)round((double)dims[0]/(double)sbin);
  blocks[1] = (int)round((double)dims[1]/(double)sbin);
  double *hist = (double *)mxCalloc(blocks[0]*blocks[1]*9, sizeof(double));
  double *norm = (double *)mxCalloc(blocks[0]*blocks[1], sizeof(double));

  // memory for HOG features
  int out[3];
  out[0] = max(blocks[0]-2, 0);
  out[1] = max(blocks[1]-2, 0);
  out[2] = 9;//27+4+1;
  mxArray *mxfeat = mxCreateNumericArray(3, out, mxDOUBLE_CLASS, mxREAL);
  double *feat = (double *)mxGetPr(mxfeat);
  
  int visible[2];
  visible[0] = blocks[0]*sbin;
  visible[1] = blocks[1]*sbin;
  
  for (int x = 1; x < visible[1]-1; x++) {
    for (int y = 1; y < visible[0]-1; y++) {
      // first flow channel
      double *s = fim + min(x, dims[1]-2)*dims[0] + min(y, dims[0]-2);     
      double dx = *s; // u channel

      // second flow channel
      s += dims[0]*dims[1];
      double dy= *s; // v channel
      double v=dx*dx + dy*dy;  //flow mag      

      // snap to one of orientations
      double best_dot = 0;
      int best_o = 0;
      for (int o = 0; o < 9; o++) {
	double dot = uu[o]*dx + vv[o]*dy;
	if (dot > best_dot) {
	  best_dot = dot;
	  best_o = o;
	} else if (-dot > best_dot) {
	  best_dot = -dot;
	  best_o = o; //o+9;
	}
      }
      
      // add to 4 histograms around pixel using linear interpolation
      double xp = ((double)x+0.5)/(double)sbin - 0.5;
      double yp = ((double)y+0.5)/(double)sbin - 0.5;
      int ixp = (int)floor(xp);
      int iyp = (int)floor(yp);
      double vx0 = xp-ixp;
      double vy0 = yp-iyp;
      double vx1 = 1.0-vx0;
      double vy1 = 1.0-vy0;
      v = sqrt(v);

      if (ixp >= 0 && iyp >= 0) {
	*(hist + ixp*blocks[0] + iyp + best_o*blocks[0]*blocks[1]) += 
	  vx1*vy1*v;
      }

      if (ixp+1 < blocks[1] && iyp >= 0) {
	*(hist + (ixp+1)*blocks[0] + iyp + best_o*blocks[0]*blocks[1]) += 
	  vx0*vy1*v;
      }

      if (ixp >= 0 && iyp+1 < blocks[0]) {
	*(hist + ixp*blocks[0] + (iyp+1) + best_o*blocks[0]*blocks[1]) += 
	  vx1*vy0*v;
      }

      if (ixp+1 < blocks[1] && iyp+1 < blocks[0]) {
	*(hist + (ixp+1)*blocks[0] + (iyp+1) + best_o*blocks[0]*blocks[1]) += 
	  vx0*vy0*v;
      }
    }
  }

  // compute energy in each block by summing over orientations
  for (int o = 0; o < 9; o++) {
    double *src1 = hist + o*blocks[0]*blocks[1];
//    double *src2 = hist + (o+9)*blocks[0]*blocks[1];
    double *dst = norm;
    double *end = norm + blocks[1]*blocks[0];
    while (dst < end) {
      //*(dst++) += (*src1 + *src2) * (*src1 + *src2);
	*(dst++) += (*src1) * (*src1);
      src1++;
      //src2++;
    }
  }

  // compute features
  for (int x = 0; x < out[1]; x++) {
    for (int y = 0; y < out[0]; y++) {
      double *dst = feat + x*out[0] + y;      
      double *src, *p, n1, n2, n3, n4;

      p = norm + (x+1)*blocks[0] + y+1;
      n1 = 1.0 / sqrt(*p + *(p+1) + *(p+blocks[0]) + *(p+blocks[0]+1) + eps);
      p = norm + (x+1)*blocks[0] + y;
      n2 = 1.0 / sqrt(*p + *(p+1) + *(p+blocks[0]) + *(p+blocks[0]+1) + eps);
      p = norm + x*blocks[0] + y+1;
      n3 = 1.0 / sqrt(*p + *(p+1) + *(p+blocks[0]) + *(p+blocks[0]+1) + eps);
      p = norm + x*blocks[0] + y;      
      n4 = 1.0 / sqrt(*p + *(p+1) + *(p+blocks[0]) + *(p+blocks[0]+1) + eps);
/*
      double t1 = 0;
      double t2 = 0;
      double t3 = 0;
      double t4 = 0;

      // contrast-sensitive features
      src = hist + (x+1)*blocks[0] + (y+1);
      for (int o = 0; o < 18; o++) {
	double h1 = min(*src * n1, 0.2);
	double h2 = min(*src * n2, 0.2);
	double h3 = min(*src * n3, 0.2);
	double h4 = min(*src * n4, 0.2);
	*dst = 0.5 * (h1 + h2 + h3 + h4);
	t1 += h1;
	t2 += h2;
	t3 += h3;
	t4 += h4;
	dst += out[0]*out[1];
	src += blocks[0]*blocks[1];
      }
*/

      // contrast-insensitive features
      src = hist + (x+1)*blocks[0] + (y+1);
      for (int o = 0; o < 9; o++) {
        double sum = *src + *(src + 9*blocks[0]*blocks[1]);
        double h1 = sum*n1; //min(sum * n1, 0.2);
        double h2 = sum*n2; //min(sum * n2, 0.2);
        double h3 = sum*n3; //min(sum * n3, 0.2);
        double h4 = sum*n4; //min(sum * n4, 0.2);
        *dst = 0.5 * (h1 + h2 + h3 + h4);
        dst += out[0]*out[1];
        src += blocks[0]*blocks[1];
      }
/*
      // texture features
      *dst = 0.2357 * t1;
      dst += out[0]*out[1];
      *dst = 0.2357 * t2;
      dst += out[0]*out[1];
      *dst = 0.2357 * t3;
      dst += out[0]*out[1];
      *dst = 0.2357 * t4;

      // truncation feature
      dst += out[0]*out[1];
      *dst = 0;
*/
    }
  }

  mxFree(hist);
  mxFree(norm);
  return mxfeat;
}

// matlab entry point
// F = features(image, bin)
// image should be color with double values
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) { 
  if (nrhs != 2)
    mexErrMsgTxt("Wrong number of inputs"); 
  if (nlhs != 1)
    mexErrMsgTxt("Wrong number of outputs");
  plhs[0] = process(prhs[0], prhs[1]);
}


