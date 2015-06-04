# Inherit common PX stuff
$(call inherit-product, vendor/px/config/common.mk)

# Include PX audio files
include vendor/px/config/cm_audio.mk

# Optional PX packages
PRODUCT_PACKAGES += \
    Galaxy4 \
    HoloSpiralWallpaper \
    LiveWallpapers \
    LiveWallpapersPicker \
    MagicSmokeWallpapers \
    NoiseField \
    PhaseBeam \
    VisualizationWallpapers \
    PhotoTable \
    SoundRecorder \
    PhotoPhase

# Extra tools in PX
PRODUCT_PACKAGES += \
    vim \
    zip \
    unrar
