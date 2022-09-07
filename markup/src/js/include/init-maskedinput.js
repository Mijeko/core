import Inputmask from "maskedinput";

document.addEventListener('DOMContentLoaded', () => {
    let russsianPhone = document.querySelectorAll(".js-mask-ru");

    if (russsianPhone) {
        russsianPhone.forEach(el => {
            let im = new Inputmask("+7 (999) 999 99-99", {placeholder: "+7 (___) ___ __ __"});
            im.mask(el);
        });
    }


    let timeMask = document.querySelectorAll(".js-time-mask");
    if (timeMask) {
        timeMask.forEach(el => {
            let im = new Inputmask("99:99:99");
            im.mask(el);
        });
    }
});
