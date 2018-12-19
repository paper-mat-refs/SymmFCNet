--
-- code derived from https://github.com/soumith/dcgan.torch
--

local util = {}

require 'torch'
function printNet(net)

    for i = 1, net:size(1) do
        print(string.format("%d: %s", i, net.modules[i]))
    end
    
end
function util.normalize(img)
  -- rescale image to 0 .. 1
  local min = img:min()
  local max = img:max()
  
  img = torch.FloatTensor(img:size()):copy(img)
  img:add(-min):mul(1/(max-min))
  return img
end

function util.normalizeBatch(batch)
  for i = 1, batch:size(1) do
    batch[i] = util.normalize(batch[i]:squeeze())
  end
  return batch
end

function util.basename_batch(batch)
  for i = 1, #batch do
    batch[i] = paths.basename(batch[i])
  end
  return batch
end



-- default preprocessing
--
-- Preprocesses an image before passing it to a net
-- Converts from RGB to BGR and rescales from [0,1] to [-1,1]
function util.preprocess(img)
    -- RGB to BGR
    local perm = torch.LongTensor{3, 2, 1}
    img = img:index(1, perm)
    
    -- -- [0,1] to [-1,1]
    -- img = img:mul(2):add(-1)
    
    -- -- check that input is in expected range
    -- assert(img:max()<=1,"badly scaled inputs")
    -- assert(img:min()>=-1,"badly scaled inputs")
    
    return img
end

-- Undo the above preprocessing.
function util.deprocess(img)
    -- BGR to RGB
    local perm = torch.LongTensor{3, 2, 1}
    img = img:index(1, perm)
    
    -- [-1,1] to [0,1]
    -- 这里也改了，直接时0到1
    -- img = img:add(1):div(2)

    return img
end
function util.deprocess_light(imgtmp)
  -- BGR to RGB
  -- local perm = torch.LongTensor{3, 2, 1}
  -- img = img:index(1, perm)

  -- img = torch.clamp(img,0,1)
  -- Img = img:div(2.5)
  -- print(torch.max(img))
  img = torch.sum(imgtmp,1):clone()
  -- img = imgtmp:clone()
  img = (img-torch.min(img)):div(torch.max(img)-torch.min(img))
  -- print(img:size())
  -- print(torch.sum(img,1):size())
  -- error('sssssssssssssssssss')
  return img
end
function util.deprocess_light_tmp(imgtmp)
  -- BGR to RGB
  -- local perm = torch.LongTensor{3, 2, 1}
  -- img = img:index(1, perm)

  -- img = torch.clamp(img,0,1)
  -- Img = img:div(2.5)
  -- print(torch.max(img))
  -- img = torch.sum(imgtmp,1):clone()
  img = (imgtmp-torch.min(imgtmp)):div(torch.max(imgtmp)-torch.min(imgtmp))
  -- print(img:size())
  -- print(torch.sum(img,1):size())
  -- error('sssssssssssssssssss')
  return img
end
function util.deprocess_vgg(img)
    -- BGR to RGB
    -- [-1,1] to [0,1]
    
    -- img = img:add(1):div(2)
    
    return img
end
function util.preprocess_batch(batch)
  for i = 1, batch:size(1) do
    batch[i] = util.preprocess(batch[i]:squeeze())
  end
  return batch
end

function util.deprocess_batch(batch)
  for i = 1, batch:size(1) do
   batch[i] = util.deprocess(batch[i]:squeeze())
  end
return batch
end

function util.deprocess_batch_light(batch)
  for i = 1, batch:size(1) do
   batch[i] = util.deprocess_light_tmp(batch[i]:squeeze())
  end
return batch
end

function util.deprocess_batch_vgg(batch)
  for i = 1, batch:size(1) do
   batch[i] = util.deprocess_vgg(batch[i]:squeeze())
  end
return batch
end
-- preprocessing specific to colorization

function util.deprocessLAB(L, AB)
    local L2 = torch.Tensor(L:size()):copy(L)
    if L2:dim() == 3 then
      L2 = L2[{1, {}, {} }]
    end
    local AB2 = torch.Tensor(AB:size()):copy(AB)
    AB2 = torch.clamp(AB2, -1.0, 1.0)
--    local AB2 = AB
    L2 = L2:add(1):mul(50.0)
    AB2 = AB2:mul(110.0)
    
    L2 = L2:reshape(1, L2:size(1), L2:size(2))
    
    im_lab = torch.cat(L2, AB2, 1)
    im_rgb = torch.clamp(image.lab2rgb(im_lab):mul(255.0), 0.0, 255.0)/255.0
    
    return im_rgb
end

function util.deprocessL(L)
    local L2 = torch.Tensor(L:size()):copy(L)
    L2 = L2:add(1):mul(255.0/2.0)
    
    if L2:dim()==2 then
      L2 = L2:reshape(1,L2:size(1),L2:size(2))
    end
    L2 = L2:repeatTensor(L2,3,1,1)/255.0
    
    return L2
end

function util.deprocessL_batch(batch)
  local batch_new = {}
  for i = 1, batch:size(1) do
    batch_new[i] = util.deprocessL(batch[i]:squeeze())
  end
  return batch_new
end

function util.deprocessLAB_batch(batchL, batchAB)
  local batch = {}
  
  for i = 1, batchL:size(1) do
    batch[i] = util.deprocessLAB(batchL[i]:squeeze(), batchAB[i]:squeeze())
  end
  
  return batch
end


function util.scaleBatch(batch,s1,s2)
  local scaled_batch = torch.Tensor(batch:size(1),batch:size(2),s1,s2)
  for i = 1, batch:size(1) do
   scaled_batch[i] = image.scale(batch[i],s1,s2):squeeze()
  end
  return scaled_batch
end



function util.toTrivialBatch(input)
    return input:reshape(1,input:size(1),input:size(2),input:size(3))
end
function util.fromTrivialBatch(input)
    return input[1]
end



function util.scaleImage(input, loadSize)
    -- replicate bw images to 3 channels
    if input:size(1)==1 then
      input = torch.repeatTensor(input,3,1,1)
    end
    
    input = image.scale(input, loadSize, loadSize)
    
    return input
end

function util.getAspectRatio(path)
  local input = image.load(path, 3, 'float')
  local ar = input:size(3)/input:size(2)
  return ar
end

function util.loadImage(path, loadSize, nc)
    local input = image.load(path, 3, 'float')
    input= util.preprocess(util.scaleImage(input, loadSize))
    
    if nc == 1 then
        input = input[{{1}, {}, {}}]
    end
    
    return input 
end



-- TO DO: loading code is rather hacky; clean it up and make sure it works on all types of nets / cpu/gpu configurations
function util.load(filename, opt)
  if opt.cudnn>0 then
    require 'cudnn'
  end
  
  if opt.gpu > 0 then 
    require 'cunn'
  end

  local net = torch.load(filename)

  if opt.gpu > 0 then
  	net:cuda()

    -- calling cuda on cudnn saved nngraphs doesn't change all variables to cuda, so do it below
    if net.forwardnodes then
      for i=1,#net.forwardnodes do
          if net.forwardnodes[i].data.module then
            net.forwardnodes[i].data.module:cuda()
          end
      end
    end
  else
    net:float()
  end
  net:apply(function(m) if m.weight then 
  m.gradWeight = m.weight:clone():zero(); 
  m.gradBias = m.bias:clone():zero(); end end)
  return net
end

function util.cudnn(net)
  require 'cudnn'
  require 'util/cudnn_convert_custom'
  return cudnn_convert_custom(net, cudnn)
end

function util.containsValue(table, value)
  for k, v in pairs(table) do 
    if v == value then return true end
  end
  return false
end

function printNet(m)
  local name = torch.type(m)
  print(name)
end


-- Return the mapColor, the same size of mapPos
-- refMapColor: 3*H*W, [0,1]
-- mapPos:      N*2*H*W  must be scale to [-1, 1]
function get_mapcolor(mapPos, refMapColor)
  assert(refMapColor:dim() == 3)
  m_N, m_H, m_W = mapPos:size(1), mapPos:size(3), mapPos:size(4)
  H, W = refMapColor:size(2), refMapColor:size(3)

  outMapColor = torch.zeros(m_N, 3, m_H, m_W)
  mapPos = torch.clamp(mapPos, -1, 1)
  refMapColor = torch.clamp(refMapColor, -1, 1)

  mapPos[{{}, {1}, {}, {}}] = (mapPos[{{}, {1}, {}, {}}]+1)/2 *(H-1) + 1
  mapPos[{{}, {2}, {}, {}}] = (mapPos[{{}, {2}, {}, {}}]+1)/2 *(W-1) + 1
  mapPos = mapPos:int()

  for bs = 1, m_N do
      for i = 1, m_H do
          for j = 1, m_W do
              flowValueX = mapPos[{bs, 1, i, j}]
              flowValueY = mapPos[{bs, 2, i, j}]
              outMapColor[{{bs},{},{i},{j}}] = refMapColor[{{},{flowValueX},{flowValueY}}]
          end
      end
  end
  return outMapColor
end


return util
