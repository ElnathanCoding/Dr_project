from image_quality import check_image_quality


image = "test.png"


result, message = check_image_quality(image)


print("Quality Check:", result)
print("Message:", message)