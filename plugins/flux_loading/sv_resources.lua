local config = flux.loading.config
if config.enabled and config.slideshow.enabled then
    for _, slide in ipairs(config.slideshow.slides) do
        resource.AddFile("materials/" .. slide.image)
    end
end
