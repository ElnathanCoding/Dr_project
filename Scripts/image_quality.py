import cv2
import numpy as np


def retina_color_score(img):
    """
    Checks if image has retinal-like red/orange characteristics
    """

    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

    lower_red = np.array([0, 30, 20])
    upper_red = np.array([30, 255, 255])

    mask = cv2.inRange(hsv, lower_red, upper_red)

    red_ratio = np.sum(mask > 0) / mask.size

    return red_ratio



def circular_fov_score(img):
    """
    Detects if image contains a circular fundus field
    """

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    gray = cv2.medianBlur(gray, 5)

    circles = cv2.HoughCircles(
        gray,
        cv2.HOUGH_GRADIENT,
        dp=1.2,
        minDist=100,
        param1=50,
        param2=40,
        minRadius=50,
        maxRadius=min(img.shape[:2])//2
    )

    if circles is not None:
        return 1

    return 0



def texture_score(img):
    """
    Checks for retinal-like texture patterns
    """

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    edges = cv2.Canny(gray, 50, 150)

    edge_ratio = np.sum(edges > 0) / edges.size

    return edge_ratio



def corner_darkness_score(img):
    """
    Real fundus photos are captured through a circular aperture, so the
    four corners of the image are almost always black/near-black (the
    camera vignette). Photos, illustrations, and screenshots essentially
    never have this — their corners usually contain scene content.

    Returns the fraction of the four corner patches that are "dark enough"
    (mean brightness below a threshold), from 0.0 to 1.0.
    """

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    h, w = gray.shape

    # Corner patch size: 10% of the image's smaller dimension
    patch = max(10, int(min(h, w) * 0.10))

    corners = [
        gray[0:patch, 0:patch],                 # top-left
        gray[0:patch, w - patch:w],              # top-right
        gray[h - patch:h, 0:patch],              # bottom-left
        gray[h - patch:h, w - patch:w],          # bottom-right
    ]

    DARK_THRESHOLD = 40  # mean brightness below this counts as "black"

    dark_corners = sum(1 for c in corners if np.mean(c) < DARK_THRESHOLD)

    return dark_corners / 4.0



def check_image_quality(image_path):

    img = cv2.imread(image_path)


    if img is None:
        return False, "Invalid image file"



    height, width = img.shape[:2]


    # ==========================
    # Resolution Check
    # ==========================

    if width < 200 or height < 200:
        return False, "Image resolution is too low"



    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)



    # ==========================
    # Brightness Check
    # ==========================

    brightness = np.mean(gray)

    if brightness < 20:
        return False, "Image is too dark"

    if brightness > 240:
        return False, "Image is overexposed"



    # ==========================
    # Blur Check
    # ==========================

    blur_value = cv2.Laplacian(
        gray,
        cv2.CV_64F
    ).var()


    if blur_value < 50:
        return False, "Image is too blurry"



    # ==========================
    # Retina Validation
    # ==========================

    retina_score = 0


    # Color (max 25 points)
    red_score = retina_color_score(img)

    if red_score > 0.15:
        retina_score += 25


    # Circular shape (max 20 points)
    circle_score = circular_fov_score(img)

    if circle_score == 1:
        retina_score += 20


    # Texture (max 20 points)
    texture = texture_score(img)

    if 0.02 < texture < 0.35:
        retina_score += 20


    # Corner darkness / fundus vignette (max 35 points — strongest signal)
    corner_score = corner_darkness_score(img)

    retina_score += corner_score * 35


    # ==========================
    # Final Decision
    # ==========================
    print("DEBUG - retina_score:", retina_score)
    if retina_score < 65:
        return False, (
            f"Not a retinal fundus image "
            f"(Retina confidence: {retina_score:.0f}%)"
        )


    return True, (
        f"Image quality acceptable "
        f"(Retina confidence: {retina_score:.0f}%)"
    )