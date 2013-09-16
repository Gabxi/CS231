#ifndef CAFFEINE_VISION_LAYERS_HPP_
#define CAFFEINE_VISION_LAYERS_HPP_

#include "caffeine/layer.hpp"

namespace caffeine {

template <typename Dtype>
class NeuronLayer : public Layer<Dtype> {
 public:
  explicit NeuronLayer(const LayerParameter& param)
     : Layer<Dtype>(param) {};
  virtual void SetUp(const vector<Blob<Dtype>*>& bottom,
      vector<Blob<Dtype>*>* top);
};

template <typename Dtype>
class ReLULayer : public NeuronLayer<Dtype> {
 public:
  explicit ReLULayer(const LayerParameter& param)
      : NeuronLayer<Dtype>(param) {};
 protected:
  virtual void Forward_cpu(const vector<Blob<Dtype>*>& bottom,
      vector<Blob<Dtype>*>* top);
  virtual void Forward_gpu(const vector<Blob<Dtype>*>& bottom,
      vector<Blob<Dtype>*>* top);

  virtual Dtype Backward_cpu(const vector<Blob<Dtype>*>& top,
      const bool propagate_down, vector<Blob<Dtype>*>* bottom);
  virtual Dtype Backward_gpu(const vector<Blob<Dtype>*>& top,
      const bool propagate_down, vector<Blob<Dtype>*>* bottom);
};

template <typename Dtype>
class DropoutLayer : public NeuronLayer<Dtype> {
 public:
  explicit DropoutLayer(const LayerParameter& param)
      : NeuronLayer<Dtype>(param) {};
  virtual void SetUp(const vector<Blob<Dtype>*>& bottom,
      vector<Blob<Dtype>*>* top);
 protected:
  virtual void Forward_cpu(const vector<Blob<Dtype>*>& bottom,
      vector<Blob<Dtype>*>* top);
  virtual void Forward_gpu(const vector<Blob<Dtype>*>& bottom,
      vector<Blob<Dtype>*>* top);

  virtual Dtype Backward_cpu(const vector<Blob<Dtype>*>& top,
      const bool propagate_down, vector<Blob<Dtype>*>* bottom);
  virtual Dtype Backward_gpu(const vector<Blob<Dtype>*>& top,
      const bool propagate_down, vector<Blob<Dtype>*>* bottom);
 private:
  shared_ptr<Blob<float> > rand_mat_;
  shared_ptr<UniformFiller<float> > filler_;
};





}  // namespace caffeine

#endif  // CAFFEINE_VISION_LAYERS_HPP_

