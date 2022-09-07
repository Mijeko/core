let elements = document.querySelectorAll('.js-phone-mask');

if (elements) {
    elements.forEach((element) => {
        element.textContent = element.textContent.replace(/(\d{1})(\d{3})(\d{3})(\d{2})(\d{2})/, '$1 ($2) $3 $4-$5');
    });
}

let elementsWorld = document.querySelectorAll('.js-phone-mask-8800');

if (elementsWorld) {
    elementsWorld.forEach((element) => {
        element.textContent = element.textContent.replace(/(\d{1})(\d{3})(\d{3})(\d{2})(\d{2})/, '$1 $2 $3 $4 $5');
    });
}