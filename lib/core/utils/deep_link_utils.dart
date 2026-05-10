class DeepLinkUtils {
  static const String baseUrl = 'https://royal-pixel.web.app';
  static const String customScheme = 'royalpixels';

  static String getWallpaperLink(String wallpaperId) {
    // We share the https link because it can fallback to a website or play store
    return '$baseUrl/wallpaper/$wallpaperId';
  }

  static String getCustomSchemeLink(String wallpaperId) {
    return '$customScheme://wallpaper?id=$wallpaperId';
  }
}
